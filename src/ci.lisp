(uiop:define-package #:cl-telegram-bot/ci
  (:use #:cl)
  (:import-from #:40ants-ci/workflow
                #:defworkflow)
  (:import-from #:40ants-ci/jobs/linter))
(in-package #:cl-telegram-bot/ci)


(defworkflow linter
  :on-pull-request t
  :cache t
  :jobs ((40ants-ci/jobs/linter:linter)))
