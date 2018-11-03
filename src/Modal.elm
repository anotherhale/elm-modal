module Modal exposing
    ( ClosingAnimation(..)
    , ClosingEffect(..)
    , Config
    , Model
    , Msg
    , OpenedAnimation(..)
    , OpeningAnimation(..)
    , animationEnd
    , closeModal
    , cmdGetWindowSize
    , initModel
    , newConfig
    , openModal
    , setBody
    , setBodyBorderRadius
    , setBodyCss
    , setBodyFromTop
    , setBodyWith
    , setClosingAnimation
    , setClosingEffect
    , setFooter
    , setFooterCss
    , setHeader
    , setHeaderCss
    , setOpenedAnimation
    , setOpeningAnimation
    , subscriptions
    , update
    , view
    )

import Browser.Dom exposing (getViewport)
import Browser.Events exposing (onResize)
import Css
import Css.Animations as Animations
import Css.Transitions as Transitions
import History exposing (History(..), create, current, forward, rewind, rewindAll)
import Html
import Html.Styled as Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (on, onClick)
import Json.Decode as Json
import Task
import VirtualDom



-- Model


type Model msg
    = Opening (Config msg)
    | Opened (Config msg)
    | Closing (Config msg)
    | Closed


initModel : Model msg
initModel =
    Closed



-- Commands


cmdGetWindowSize : Cmd (Msg msg)
cmdGetWindowSize =
    Task.perform
        (\{ viewport } ->
            GetWindowSize (round viewport.width) (round viewport.height)
        )
        getViewport



-- Subscriptions


subscriptions : Sub (Msg msg)
subscriptions =
    onResize GetWindowSize



-- Msg


type Msg msg
    = OpenModal (Config msg)
    | CloseModal
    | AnimationEnd
    | GetWindowSize Int Int



-- Types


type OpeningAnimation
    = FromTop
    | FromRight
    | FromBottom
    | FromLeft


type OpenedAnimation
    = OpenFromTop
    | OpenFromRight
    | OpenFromBottom
    | OpenFromLeft


type ClosingAnimation
    = ToTop
    | ToRight
    | ToBottom
    | ToLeft


type ClosingEffect
    = WithoutAnimate
    | WithAnimate


type WindowSize
    = WindowSize { width : Int, height : Int }


type BodySettings
    = BodySettings
        { fromTop : Css.Px
        , width : History.History Css.Px
        , center : Css.Pct
        , borderRadius : Css.Px
        }


type History a
    = History a (List a)


type alias Header msg =
    Styled.Html msg


type alias Body msg =
    Styled.Html msg


type alias Footer msg =
    Styled.Html msg


type Config msg
    = Config
        { openingAnimation : OpeningAnimation
        , openedAnimation : OpenedAnimation
        , closingAnimation : ClosingAnimation
        , closingEffect : ClosingEffect
        , headerCss : String
        , header : Header msg
        , bodyCss : String
        , body : Body msg
        , footerCss : String
        , footer : Footer msg
        , modalBodySettings : BodySettings
        , tagger : Msg msg -> msg
        , windowSize : WindowSize
        }


{-| Create a new configuration for Modal.

    newConfig |> setHeaderCss "header--bg-color"

-}
newConfig : (Msg msg -> msg) -> Config msg
newConfig tagger =
    Config
        { openingAnimation = FromTop
        , openedAnimation = OpenFromTop
        , closingAnimation = ToTop
        , closingEffect = WithAnimate
        , headerCss = ""
        , header = text ""
        , bodyCss = ""
        , body = text ""
        , footerCss = ""
        , footer = text ""
        , modalBodySettings =
            BodySettings
                { fromTop = Css.px 200
                , width = create (Css.px 600)
                , center = Css.pct 33
                , borderRadius = Css.px 5
                }
        , tagger = tagger
        , windowSize =
            WindowSize { width = 0, height = 0 }
        }


openModal : (Msg msg -> msg) -> Config msg -> msg
openModal fn config =
    fn (OpenModal config)


closeModal : (Msg msg -> msg) -> msg
closeModal fn =
    fn CloseModal


animationEnd : (Msg msg -> msg) -> msg
animationEnd fn =
    fn AnimationEnd



-- Update


{-| Update the component state. In your parent update function
just add

    ModalMsg modalMsg ->
        let
            ( updatedModal, cmdModal ) =
                Modal.update modalMsg model.modal
        in
        ( { model | modal = updatedModal }
        , Cmd.map ModalMsg cmdModal
        )

-}
update : Msg msg -> Model msg -> ( Model msg, Cmd (Msg msg) )
update msg model =
    case msg of
        OpenModal config ->
            ( Opening config
            , cmdGetWindowSize
            )

        CloseModal ->
            ( setModalState model
            , Cmd.none
            )

        AnimationEnd ->
            ( setModalState model
            , Cmd.none
            )

        GetWindowSize width height ->
            ( setModalBodyPosition width height model
            , Cmd.none
            )



-- View


{-| Render a view of modal window

    Modal.view model.modal

-}
view : Model msg -> Html.Html msg
view modal =
    Styled.toUnstyled <|
        case modal of
            Opening (Config config) ->
                div [ modalFade ]
                    [ modalBodyView
                        (Just AnimationEnd)
                        (openingAnimationClass config.openingAnimation config.modalBodySettings)
                        (Config config)
                    ]

            Opened (Config config) ->
                div [ modalFade ]
                    [ modalBodyView
                        Nothing
                        (openedAnimationClass config.openedAnimation config.modalBodySettings)
                        (Config config)
                    ]

            Closing (Config config) ->
                div
                    [ modalFade
                    , modalClose
                    , closingEffectClass config.closingEffect
                    ]
                    [ modalBodyView
                        (Just AnimationEnd)
                        (closingAnimationClass config.closingAnimation config.modalBodySettings)
                        (Config config)
                    ]

            Closed ->
                text ""


{-| @priv
View of modal body
-}
modalBodyView : Maybe (Msg msg) -> Attribute msg -> Config msg -> Html msg
modalBodyView animationTagger animation (Config config) =
    let
        animTgr =
            case animationTagger of
                Just msg ->
                    onAnimationEnd (config.tagger msg)

                Nothing ->
                    css []
    in
    div
        [ modalBody
            config.modalBodySettings
        , animation
        , animTgr
        ]
        [ div [ class ("modal__header " ++ config.headerCss) ]
            [ config.header ]
        , div [ class ("modal__content " ++ config.bodyCss) ]
            [ config.body ]
        , div [ class ("modal__footer " ++ config.footerCss) ]
            [ config.footer ]
        ]



-- Setters for Config


{-| Set styles as css of modal's body

    Modal.setBodyCss "body--bg-color" config

-}
setBodyCss : String -> Config msg -> Config msg
setBodyCss newBodyCss config =
    let
        fn (Config c) =
            Config { c | bodyCss = newBodyCss }
    in
    mapConfig fn config


{-| Set styles and msg to the body of modal

    bodySuccess : Html msg
    bodySuccess =
        div [][ text "Hello from body modal." ]

    Modal.setBody bodySuccess config

-}
setBody : VirtualDom.Node msg -> Config msg -> Config msg
setBody newBody config =
    let
        fn (Config c) =
            Config { c | body = Styled.fromUnstyled newBody }
    in
    mapConfig fn config


setHeaderCss : String -> Config msg -> Config msg
setHeaderCss newHeaderCss config =
    let
        fn (Config c) =
            Config { c | headerCss = newHeaderCss }
    in
    mapConfig fn config


setHeader : VirtualDom.Node msg -> Config msg -> Config msg
setHeader newHeader config =
    let
        fn (Config c) =
            Config { c | header = Styled.fromUnstyled newHeader }
    in
    mapConfig fn config


setFooterCss : String -> Config msg -> Config msg
setFooterCss newFooterCss config =
    let
        fn (Config c) =
            Config { c | footerCss = newFooterCss }
    in
    mapConfig fn config


setFooter : VirtualDom.Node msg -> Config msg -> Config msg
setFooter newFooter config =
    let
        fn (Config c) =
            Config { c | footer = Styled.fromUnstyled newFooter }
    in
    mapConfig fn config


setOpeningAnimation : OpeningAnimation -> Config msg -> Config msg
setOpeningAnimation opening config =
    let
        fn (Config c) =
            Config { c | openingAnimation = opening }
    in
    mapConfig fn config


setOpenedAnimation : OpenedAnimation -> Config msg -> Config msg
setOpenedAnimation opened config =
    let
        fn (Config c) =
            Config { c | openedAnimation = opened }
    in
    mapConfig fn config


setClosingAnimation : ClosingAnimation -> Config msg -> Config msg
setClosingAnimation closing config =
    let
        fn (Config c) =
            Config { c | closingAnimation = closing }
    in
    mapConfig fn config


setClosingEffect : ClosingEffect -> Config msg -> Config msg
setClosingEffect newClosingEffect config =
    let
        fn (Config c) =
            Config { c | closingEffect = newClosingEffect }
    in
    mapConfig fn config


setBodyWith : Float -> Config msg -> Config msg
setBodyWith width config =
    let
        setWidth : Float -> BodySettings -> BodySettings
        setWidth newWidth (BodySettings bs) =
            BodySettings { bs | width = create (Css.px newWidth) }
    in
    setBodySettings (setWidth width) config


setBodyFromTop : Float -> Config msg -> Config msg
setBodyFromTop top config =
    let
        setTop : Float -> BodySettings -> BodySettings
        setTop newTop (BodySettings bs) =
            BodySettings { bs | fromTop = Css.px newTop }
    in
    setBodySettings (setTop top) config


setBodyBorderRadius : Float -> Config msg -> Config msg
setBodyBorderRadius borderRad config =
    let
        setBorderRadius : Float -> BodySettings -> BodySettings
        setBorderRadius newBorderRad (BodySettings bs) =
            BodySettings { bs | borderRadius = Css.px newBorderRad }
    in
    setBodySettings (setBorderRadius borderRad) config


setBodySettings : (BodySettings -> BodySettings) -> Config msg -> Config msg
setBodySettings updateFn (Config c) =
    Config { c | modalBodySettings = updateFn c.modalBodySettings }



-- Private setters for modal window


openingAnimationClass : OpeningAnimation -> BodySettings -> Attribute msg
openingAnimationClass animation bodySettings =
    case animation of
        FromTop ->
            modalTopOpening bodySettings

        FromRight ->
            modalRigthOpening bodySettings

        FromBottom ->
            modalBottomOpening bodySettings

        FromLeft ->
            modalLeftOpening bodySettings


openedAnimationClass : OpenedAnimation -> BodySettings -> Attribute msg
openedAnimationClass animation bodySettings =
    case animation of
        OpenFromTop ->
            modalOpenFromTop bodySettings

        OpenFromRight ->
            modalOpenFromRigth bodySettings

        OpenFromBottom ->
            modalOpenFromBottom bodySettings

        OpenFromLeft ->
            modalOpenFromLeft bodySettings


closingAnimationClass : ClosingAnimation -> BodySettings -> Attribute msg
closingAnimationClass animation bodySettings =
    case animation of
        ToTop ->
            modalTopClosing bodySettings

        ToRight ->
            modalRightClosing bodySettings

        ToBottom ->
            modalBottomClosing bodySettings

        ToLeft ->
            modalLeftClosing bodySettings


closingEffectClass : ClosingEffect -> Attribute msg
closingEffectClass animation =
    case animation of
        WithoutAnimate ->
            css [ Css.display Css.none ]

        WithAnimate ->
            css []



-- Private css style and animations for modal window


modalFade : Attribute msg
modalFade =
    css
        [ Css.position Css.absolute
        , Css.top (Css.px 0)
        , Css.bottom (Css.px 0)
        , Css.left (Css.px 0)
        , Css.right (Css.px 0)
        , Css.backgroundColor (Css.rgba 0 0 0 0.5)
        , Css.zIndex (Css.int 999)
        , Css.overflow Css.hidden
        ]


modalBody : BodySettings -> Attribute msg
modalBody (BodySettings body) =
    css
        [ Css.displayFlex
        , Css.flexDirection Css.column
        , Css.alignItems Css.center
        , Css.property "align-content" "space-between"
        , Css.width (current body.width)
        , Css.height Css.auto
        , Css.borderRadius body.borderRadius
        , Css.boxShadow4 (Css.px 0) (Css.px 3) (Css.px 7) (Css.rgba 0 0 0 0.75)
        , Css.backgroundColor (Css.rgb 255 255 255)
        ]



-- Opening animations


modalTopOpening : BodySettings -> Attribute msg
modalTopOpening (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" "0"
                    ]
                  )
                , ( 75
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "1s"
        , Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalRigthOpening : BodySettings -> Attribute msg
modalRigthOpening (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "0"
                    , Animations.property "right" "0"
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 75
                  , [ Animations.property "opacity" "1"
                    , Animations.property "right" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "1s"
        , Css.property "right" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalBottomOpening : BodySettings -> Attribute msg
modalBottomOpening (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" "75%"
                    ]
                  )
                , ( 75
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "1s"
        , Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalLeftOpening : BodySettings -> Attribute msg
modalLeftOpening (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" "0"
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 75
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "1s"
        , Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]



-- Open animations


modalOpenFromTop : BodySettings -> Attribute msg
modalOpenFromTop (BodySettings body) =
    css
        [ --Css.animationName
          -- (Animations.keyframes
          --     [ ( 0
          --       , [ Animations.property "opacity" "0"
          --         , Animations.property "left" body.center.value
          --         , Animations.property "top" "0"
          --         ]
          --       )
          --     , ( 75
          --       , [ Animations.property "opacity" "1"
          --         , Animations.property "left" body.center.value
          --         , Animations.property "top" body.fromTop.value
          --         ]
          --       )
          --     ]
          -- )
          -- , Css.property "animation-duration" "1s"
          Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalOpenFromRigth : BodySettings -> Attribute msg
modalOpenFromRigth (BodySettings body) =
    css
        [ Css.property "right" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalOpenFromBottom : BodySettings -> Attribute msg
modalOpenFromBottom (BodySettings body) =
    css
        [ Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]


modalOpenFromLeft : BodySettings -> Attribute msg
modalOpenFromLeft (BodySettings body) =
    css
        [ Css.property "left" body.center.value
        , Css.top body.fromTop
        , Css.position Css.absolute
        ]



-- Closing animations


modalTopClosing : BodySettings -> Attribute msg
modalTopClosing (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 100
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" "20px"
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "0.5s"
        , Css.opacity (Css.int 0)
        , Css.position Css.absolute
        , Css.property "left" body.center.value
        , Css.top (Css.px 0)
        ]


modalRightClosing : BodySettings -> Attribute msg
modalRightClosing (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "1"
                    , Animations.property "right" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 100
                  , [ Animations.property "opacity" "0"
                    , Animations.property "right" "0"
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "0.5s"
        , Css.opacity (Css.int 0)
        , Css.position Css.absolute
        , Css.right (Css.px 0)
        , Css.top body.fromTop
        ]


modalBottomClosing : BodySettings -> Attribute msg
modalBottomClosing (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 100
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" "65%"
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "0.5s"
        , Css.opacity (Css.int 0)
        , Css.position Css.absolute
        , Css.property "left" body.center.value
        ]


modalLeftClosing : BodySettings -> Attribute msg
modalLeftClosing (BodySettings body) =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "opacity" "1"
                    , Animations.property "left" body.center.value
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                , ( 100
                  , [ Animations.property "opacity" "0"
                    , Animations.property "left" "0"
                    , Animations.property "top" body.fromTop.value
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "0.5s"
        , Css.opacity (Css.int 0)
        , Css.position Css.absolute
        , Css.left (Css.px 0)
        , Css.top body.fromTop
        ]



-- Modal close animation


modalClose : Attribute msg
modalClose =
    css
        [ Css.animationName
            (Animations.keyframes
                [ ( 0
                  , [ Animations.property "background" "rgba(0, 0, 0, 0.5)"
                    ]
                  )
                , ( 100
                  , [ Animations.property "background" "rgba(0, 0, 0, 0)"
                    , Animations.property "display" "none"
                    ]
                  )
                ]
            )
        , Css.property "animation-duration" "0.5s"
        , Css.backgroundColor (Css.rgba 0 0 0 0)
        ]



-- Internal


onAnimationStart : msg -> Attribute msg
onAnimationStart msg =
    on "animationstart" (Json.succeed msg)


onAnimationIteration : msg -> Attribute msg
onAnimationIteration msg =
    on "animationiteration" (Json.succeed msg)


onAnimationEnd : msg -> Attribute msg
onAnimationEnd msg =
    on "animationend" (Json.succeed msg)


setWindowSize : Int -> Int -> Config msg -> Config msg
setWindowSize width height config =
    let
        fn (Config c) =
            Config { c | windowSize = WindowSize { width = width, height = height } }
    in
    mapConfig fn config


setModalBodyPosition width height model =
    case model of
        Opening config ->
            config
                |> setWindowSize width height
                |> setBodySettings (setBodyCenterAndWidth width)
                |> Opening

        Opened config ->
            config
                |> setWindowSize width height
                |> setBodySettings (setBodyCenterAndWidth width)
                |> Opened

        Closing config ->
            config
                |> setWindowSize width height
                |> setBodySettings (setBodyCenterAndWidth width)
                |> Closing

        Closed ->
            Closed



-- Private helpers


{-| @priv
Helper for update config
-}
mapConfig : (Config msg -> Config msg) -> Config msg -> Config msg
mapConfig fn config =
    fn config


{-| @priv
Helper for update function
-}
setModalState : Model msg -> Model msg
setModalState modal =
    case modal of
        Opening config ->
            Opened config

        Opened config ->
            Closing config

        Closing _ ->
            Closed

        Closed ->
            Closed


{-| @priv
Centering and adaptive width for modal body
-}
setBodyCenterAndWidth : Int -> BodySettings -> BodySettings
setBodyCenterAndWidth width (BodySettings bs) =
    let
        defaultBodyWidth =
            bs.width
                |> rewindAll
                |> current
                |> .numericValue

        windowWidth =
            toFloat width

        setC =
            if defaultBodyWidth >= windowWidth then
                0

            else
                50 * (1 - defaultBodyWidth / windowWidth)

        setW =
            if defaultBodyWidth < windowWidth then
                bs.width |> rewindAll

            else
                bs.width |> forward (Css.px windowWidth)
    in
    BodySettings
        { bs
            | center = Css.pct setC
            , width = setW
        }