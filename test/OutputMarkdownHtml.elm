port module OutputMarkdownHtml exposing (main)

import Html.String as Html
import Html.String.Attributes as Attr
import Markdown.Block as Block
import Markdown.Html
import Markdown.Parser as Markdown
import Markdown.Renderer


port requestHtml : (String -> msg) -> Sub msg


port printOutput : String -> Cmd msg


port error : String -> Cmd msg


printHtml : Html -> Cmd msg
printHtml renderResult =
    case renderResult of
        Ok htmlString ->
            printOutput htmlString

        Err errorString ->
            error errorString


type alias Html =
    Result String String


init flags =
    ( ()
    , Cmd.none
    )


render renderer markdown =
    markdown
        |> Markdown.parse
        |> Result.mapError deadEndsToString
        |> Result.andThen (\ast -> Markdown.Renderer.render renderer ast)


deadEndsToString deadEnds =
    deadEnds
        |> List.map Markdown.deadEndToString
        |> String.join "\n"


renderMarkdown : String -> Html
renderMarkdown markdown =
    markdown
        |> render
            { heading =
                \{ level, children } ->
                    case level of
                        Block.H1 ->
                            Html.h1 [] children

                        Block.H2 ->
                            Html.h2 [] children

                        Block.H3 ->
                            Html.h3 [] children

                        Block.H4 ->
                            Html.h4 [] children

                        Block.H5 ->
                            Html.h5 [] children

                        Block.H6 ->
                            Html.h6 [] children
            , paragraph = Html.p []
            , hardLineBreak = Html.br [] []
            , blockQuote = Html.blockquote []
            , strong =
                \children -> Html.strong [] children
            , emphasis =
                \children -> Html.em [] children
            , codeSpan =
                \content -> Html.code [] [ Html.text content ]
            , link =
                \link content ->
                    case link.title of
                        Just title ->
                            Html.a
                                [ Attr.href link.destination
                                , Attr.title title
                                ]
                                content
                                |> Ok

                        Nothing ->
                            Html.a [ Attr.href link.destination ] content
                                |> Ok
            , image =
                \imageInfo ->
                    case imageInfo.title of
                        Just title ->
                            Html.img
                                [ Attr.src imageInfo.src
                                , Attr.alt imageInfo.alt
                                , Attr.title title
                                ]
                                []
                                |> Ok

                        Nothing ->
                            Html.img
                                [ Attr.src imageInfo.src
                                , Attr.alt imageInfo.alt
                                ]
                                []
                                |> Ok
            , text =
                Html.text
            , unorderedList =
                \items ->
                    Html.ul []
                        (items
                            |> List.map
                                (\item ->
                                    case item of
                                        Block.ListItem task children ->
                                            let
                                                checkbox =
                                                    case task of
                                                        Block.NoTask ->
                                                            Html.text ""

                                                        Block.IncompleteTask ->
                                                            Html.input
                                                                [ Attr.disabled True
                                                                , Attr.checked False
                                                                , Attr.type_ "checkbox"
                                                                ]
                                                                []

                                                        Block.CompletedTask ->
                                                            Html.input
                                                                [ Attr.disabled True
                                                                , Attr.checked True
                                                                , Attr.type_ "checkbox"
                                                                ]
                                                                []
                                            in
                                            Html.li [] (checkbox :: children)
                                )
                        )
            , orderedList =
                \startingIndex items ->
                    Html.ol
                        (if startingIndex /= 1 then
                            [ Attr.start startingIndex ]

                         else
                            []
                        )
                        (items
                            |> List.map
                                (\itemBlocks ->
                                    Html.li []
                                        itemBlocks
                                )
                        )
            , html =
                htmlRenderer
            , codeBlock =
                \{ body, language } ->
                    Html.pre []
                        [ Html.code []
                            [ Html.text body
                            ]
                        ]
            , thematicBreak = Html.hr [] []
            }
        |> Result.map (List.map (Html.toString 0))
        |> Result.map (String.join "")


htmlRenderer : Markdown.Html.Renderer (List (Html.Html msg) -> Html.Html msg)
htmlRenderer =
    Markdown.Html.passthrough
        (\tag attributes blocks ->
            let
                result : Result String (List (Html.Html msg) -> Html.Html msg)
                result =
                    (\children ->
                        Html.node tag htmlAttributes children
                    )
                        |> Ok

                htmlAttributes : List (Html.Attribute msg)
                htmlAttributes =
                    attributes
                        |> List.map
                            (\{ name, value } ->
                                Attr.attribute name value
                            )
            in
            result
        )


passThroughNode nodeName =
    Markdown.Html.tag nodeName
        (\id class href children ->
            Html.node nodeName
                ([ id |> Maybe.map Attr.id
                 , class |> Maybe.map Attr.class
                 , href |> Maybe.map Attr.href
                 ]
                    |> List.filterMap identity
                )
                children
        )
        |> Markdown.Html.withOptionalAttribute "id"
        |> Markdown.Html.withOptionalAttribute "class"
        |> Markdown.Html.withOptionalAttribute "href"


type Msg
    = RequestedHtml String


type alias Model =
    ()


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestedHtml markdown ->
            ( model
            , markdown
                |> renderMarkdown
                |> printHtml
            )


main : Program () () Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = \model -> requestHtml RequestedHtml
        }
