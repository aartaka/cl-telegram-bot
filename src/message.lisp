(defpackage #:cl-telegram-bot/message
  (:use #:cl)
  (:import-from #:log4cl)
  (:import-from #:cl-telegram-bot/chat
                #:get-chat-id
                #:make-chat)
  (:import-from #:cl-telegram-bot/entities/core
                #:make-entity)
  (:import-from #:cl-telegram-bot/network
                #:make-request)
  (:import-from #:cl-telegram-bot/pipeline
                #:process)
  (:import-from #:cl-telegram-bot/bot
                #:bot)
  (:import-from #:serapeum
                #:defvar-unbound)
  (:import-from #:cl-telegram-bot/utils
                #:def-telegram-call)
  (:export
   #:send-message
   #:delete-message
   #:forward-message
   #:make-message
   #:get-text
   #:get-raw-data
   #:get-chat
   #:get-entities
   #:message
   #:get-reply-to-message
   #:reply
   #:get-forward-from
   #:get-forward-from-chat
   #:get-forward-sender-name
   #:forwarded
   #:on-message
   #:get-current-chat))
(in-package cl-telegram-bot/message)


(defvar-unbound *current-bot*
  "An internal variable to hold current bot for replying.")

(defvar-unbound *current-message*
  "An internal variable to hold current message for replying.")


(defclass message ()
  ((id :initarg :id
       :reader get-message-id)
   (text :initarg :text
         :reader get-text)
   (chat :initarg :chat
         :reader get-chat)
   (entities :initarg :entities
             :initform nil
             :reader get-entities)
   (raw-data :initarg :raw-data
             :reader get-raw-data)
   (forward-from :initarg :forward-from
                 :reader get-forward-from)
   (forward-sender-name :initarg :forward-sender-name
                        :reader get-forward-sender-name)
   (forward-from-chat :initarg :forward-from-chat
                      :reader get-forward-from-chat)))

(defmethod initialize-instance :after ((message message) &key data &allow-other-keys)
  (when data
    (setf (slot-value message 'id) (getf data :|message_id|)
          (slot-value message 'text) (getf data :|text|)
          (slot-value message 'chat) (make-chat (getf data :|chat|))
          (slot-value message 'entities) (mapcar (lambda (item)
                                                   (make-entity message item))
                                                 (getf data :|entities|))
          (slot-value message 'raw-data) data
          (slot-value message 'forward-from-chat) (when (getf data :|forward_from_chat|)
                                                    (make-chat (getf data :|forward_from_chat|)))
          (slot-value message 'forward-from) (when (getf data :|forward_from_chat|)
                                               (make-chat (getf data :|forward_from|)))
          (slot-value message 'forward-sender-name) (getf data :|forward_sender_name|))))

(defclass reply (message)
  ((reply-to-message :initarg :reply-to-message
                     :reader get-reply-to-message)))

(defmethod initialize-instance :after ((reply reply) &key data &allow-other-keys)
  (when data
    (setf (slot-value reply 'reply-to-message)
          (make-message (getf data :|reply_to_message|)))))

(defun make-message (data)
  (when data
    (let* ((class (cond
                    ((getf data :|reply_to_message|) 'reply)
                    (t 'message))))
      (make-instance class :data data))))


(defmethod print-object ((message message) stream)
  (print-unreadable-object
      (message stream :type t)
    (format stream
            "text=~A chat=~A"
            (get-text message)
            (get-chat message))))


(defun send-message (bot chat text &key
                                     parse-mode
                                     disable-web-page-preview
                                     disable-notification
                                     reply-to-message-id
                                     reply-markup)
  "https://core.telegram.org/bots/api#sendmessage"
  (log:debug "Sending message" chat text)
  (let ((options
          (append
           `(:|chat_id| ,(get-chat-id chat)
              :|text| ,text)
           (when reply-markup
             `(:|reply_markup| ,reply-markup))
           (when parse-mode
             `(:|parse_mode| ,parse-mode))
           (when disable-web-page-preview
             `(:disable_web_page_preview ,disable-web-page-preview))
           (when disable-notification
             `(:disable_notification ,disable-notification))
           (when reply-to-message-id
             `(:reply_to_message_id ,reply-to-message-id)))))
    (make-request bot "sendMessage" options)))

;; TODO: сделать так чтобы def-telegram-call работал c 
;; (def-telegram-call send-message (chat text &key
;;                                       parse-mode
;;                                       disable-web-page-preview
;;                                       disable-notification
;;                                       reply-to-message-id)
;;   "https://core.telegram.org/bots/api#sendmessage"
;;   (log:debug "Sending message" chat text)
;;   (let ((options
;;           (append
;;            `(:|chat_id| ,(get-chat-id chat)
;;              :|text| ,text)
;;            (when parse-mode
;;              `(:|parse_mode| ,parse-mode))
;;            (when disable-web-page-preview
;;              `(:disable_web_page_preview ,disable-web-page-preview))
;;            (when disable-notification
;;              `(:disable_notification ,disable-notification))
;;            (when reply-to-message-id
;;              `(:reply_to_message_id ,reply-to-message-id)))))
;;     (make-request bot "sendMessage" options)))

(defun forward-message (bot chat from-chat message &key disable-notification)
  "https://core.telegram.org/bots/api#forwardmessage"
  (let ((options
         (append (list :|chat_id| (get-chat-id chat)
                       :|from_chat_id| (get-chat-id from-chat)
                       :|message_id| (get-message-id message))
                 (when disable-notification
                   (list :|disable_notification| t)))))
    (make-request bot "forwardMessage" options)))

;; TODO: refactor

;; (defun edit-message-text (b text &key chat-id message-id inline-message-id parse-mode disable-web-page-preview reply-markup)
;;   "https://core.telegram.org/bots/api#editmessagetext"
;;   (let ((options
;;          (list
;;           (cons :text text))))
;;     (when chat-id (nconc options `((:chat_id . ,chat-id))))
;;     (when message-id (nconc options `((:message_id . ,message-id))))
;;     (when inline-message-id (nconc options `((:inline_message_id . ,inline-message-id))))
;;     (when parse-mode (nconc options `((:parse_mode . ,parse-mode))))
;;     (when disable-web-page-preview (nconc options `((:disable_web_page_preview . ,disable-web-page-preview))))
;;     (when reply-markup (nconc options `((:reply_markup . ,reply-markup))))
;;     (make-request b "editMessageText" options)))

;; (defun edit-message-caption (b &key chat-id message-id inline-message-id caption reply-markup)
;;   "https://core.telegram.org/bots/api#editmessagecaption"
;;   (let ((options '()))
;;     (when chat-id (nconc options `((:chat_id . ,chat-id))))
;;     (when message-id (nconc options `((:message_id . ,message-id))))
;;     (when inline-message-id (nconc options `((:inline_message_id . ,inline-message-id))))
;;     (when caption (nconc options `((:caption . ,caption))))
;;     (when reply-markup (nconc options `((:reply_markup . ,reply-markup))))
;;     (make-request b "editMessageCaption" options)))

;; (defun edit-message-reply-markup (b &key chat-id message-id inline-message-id reply-markup)
;;   "https://core.telegram.org/bots/api#editmessagereplymarkup"
;;   (let ((options '()))
;;     (when chat-id (nconc options `((:chat_id . ,chat-id))))
;;     (when message-id (nconc options `((:message_id . ,message-id))))
;;     (when inline-message-id (nconc options `((:inline_message_id . ,inline-message-id))))
;;     (when reply-markup (nconc options `((:reply_markup . ,reply-markup))))
;;     (make-request b "editMessageReplyMarkup" options)))

(defun delete-message (bot chat message)
  "https://core.telegram.org/bots/api#deletemessage"
  (let ((options
          (list :|chat_id| (get-chat-id chat)
                :|message_id| (get-message-id message))))
    (make-request bot "deleteMessage" options)))


(define-condition reply-immediately ()
  ((text :initarg :text
         :reader get-text)
   (args :initarg :args
         :reader get-rest-args)))


(defun reply (text
              &rest args
              &key
                parse-mode
                disable-web-page-preview
                disable-notification
                reply-to-message-id
                reply-markup)
  (declare (ignorable parse-mode
                      disable-web-page-preview
                      disable-notification
                      reply-to-message-id
                      reply-markup))
  "Works like a send-message, but only when an incoming message is processed.
   Automatically sends reply to a chat from where current message came from."
  (unless (and (boundp '*current-bot*)
               (boundp '*current-message*))
    (error "Seems (reply ~S) was called outside of processing pipeline, because no current message is available."
           text))

  (signal 'reply-immediately
          :text text
          :args args))


(defgeneric on-message (bot text)
  (:documentation "This method gets called with raw text from the message.
                   By default it does nothing."))


(defmethod on-message ((bot t) text)
  (declare (ignorable text))
  (log:warn "Ignoring messages's text. Define on-message method to process it.")
  (values))


(defmethod process ((bot t) (message message))
  "By default, just calls `process' on each entity. And after that calls (on-message bot text).

   This method binds its arguments to *current-bot* and *current-message*
   to make it easier to use (reply \"text\") in 99% usecases.

   If (reply \"text\") is called during processing of some entity or inside the on-message, then
   whole processing pipeline will be stopped and next update will be processed."
  (log:debug "Processing message" message)
  
  (let ((*current-bot* bot)
        (*current-message* message))
    
    (handler-case
        (progn (loop for entity in (get-entities message)
                     do (process bot entity))

               (on-message bot
                           (get-text message)))
      (reply-immediately (condition)
        (log:debug "Replying to" *current-message*)
        (apply #'send-message
               *current-bot*
               (get-chat *current-message*)
               (get-text condition)
               (get-rest-args condition)))))
  (values))


(defun get-current-chat ()
  "Returns a chat where currently processing message was received."
  (unless (boundp '*current-message*)
    (error "Seems (get-current-chat) was called outside of processing pipeline, because no current message is available."))

  (get-chat *current-message*))
