{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}

module Handler.Profile where

import           Import

getProfileR :: Handler Html
getProfileR = do
  (_, user) <- requireAuthPair
  defaultLayout $ do
    setTitle . toHtml $ userLoginName user <> "'s profile page"
    $(widgetFile "profile")