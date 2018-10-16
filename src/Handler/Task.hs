{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
module Handler.Task where

import           Database.Persist.Sql
import           Yesod.Form.Bootstrap3
import           Import
import           Yesod.Form.Jquery
import           RepeatInterval
import           Text.Read                      ( read
                                                , readMaybe
                                                )

repeatIntervalField :: Field Handler RepeatInterval
repeatIntervalField = Field
  { fieldParse   = \rawVals _ -> case rawVals of
    (i : u : rf : xs)
      | not $ null xs -> return $ Right $ Just $ OnWeekdays
        (map (read . unpack) xs)
        (read $ unpack rf)
      | isNothing ((readMaybe $ unpack i) :: Maybe Int) -> return
      $  Right Nothing
      | u == "Days" -> return $ Right $ Just $ Days (read $ unpack i)
                                                    (read $ unpack rf)
      | u == "Weeks" -> return $ Right $ Just $ Weeks (read $ unpack i)
                                                      (read $ unpack rf)
      | u == "Months" -> return $ Right $ Just $ Months (read $ unpack i)
                                                        (read $ unpack rf)
      | u == "Years" -> return $ Right $ Just $ Years (read $ unpack i)
                                                      (read $ unpack rf)
      | otherwise -> return $ Left "Invalid unit of time for repeat interval"
    _ -> return $ Right Nothing
  , fieldView    = \idAttr nameAttr otherAttrs eResult isReq -> case eResult of
    Right (Days n ri) -> do
      let days = []
      let u    = "Days"
      $(widgetFile "repeat-interval")
    Right (Weeks n ri) -> do
      let days = []
      let u    = "Weeks"
      $(widgetFile "repeat-interval")
    Right (Months n ri) -> do
      let days = []
      let u    = "Months"
      $(widgetFile "repeat-interval")
    Right (Years n ri) -> do
      let days = []
      let u    = "Years"
      $(widgetFile "repeat-interval")
    Right (OnWeekdays days ri) -> do
      let n = 0
      let u = ""
      $(widgetFile "repeat-interval")
    Left _ -> do
      let (n, ri, days, u) = (0, CompletionDate, [], "")
      $(widgetFile "repeat-interval")
  , fieldEnctype = UrlEncoded
  }

taskForm :: UserId -> Maybe Task -> Form Task
taskForm userId mtask =
  renderBootstrap3
      (BootstrapHorizontalForm (ColXs 1) (ColXs 3) (ColXs 0) (ColXs 8))
    $   Task
    <$> areq textField "Task Name" (taskName <$> mtask)
    <*> areq intField "Duration in Minutes" (taskDuration <$> mtask)
    <*> areq (selectField optionsEnum) "Priority" (taskPriority <$> mtask)
    <*> aopt (jqueryDayField def { jdsChangeYear = True })
             "Due Date"
             (taskDueDate <$> mtask)
    <*> aopt repeatIntervalField "Repeat Every" (taskRepeat <$> mtask)
    <*> pure False
    <*> pure userId
    <*  bootstrapSubmit ("Submit" :: BootstrapSubmit Text)

getNewTaskR :: Handler Html
getNewTaskR = do
  userId                   <- requireAuthId
  ((res, widget), enctype) <- runFormPost $ taskForm userId Nothing
  case res of
    FormSuccess t -> do
      runDB $ insert t
      setMessage "Task created"
      redirectUltDest HomeR
    _ -> do
      defaultLayout $(widgetFile "new-task")

postNewTaskR :: Handler Html
postNewTaskR = getNewTaskR

getEditTaskR :: TaskId -> Handler Html
getEditTaskR taskId = do
  userId                   <- requireAuthId
  task                     <- runDB $ get taskId
  ((res, widget), enctype) <- runFormPost $ taskForm userId $ task
  case res of
    FormSuccess t -> do
      runDB $ replace taskId t
      setMessage "Task updated"
      redirectUltDest HomeR
    _ -> defaultLayout $(widgetFile "edit-task")

postEditTaskR :: TaskId -> Handler Html
postEditTaskR = getEditTaskR

getDeleteTaskR :: TaskId -> Handler ()
getDeleteTaskR taskId = do
  setUltDestReferer
  runDB $ deleteWhere
    (   [TaskDependencyTaskId ==. taskId]
    ||. [TaskDependencyDependsOnTaskId ==. taskId]
    )
  runDB $ delete taskId
  redirectUltDest HomeR
