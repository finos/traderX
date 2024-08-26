(ns reference-service.web.socket
  (:require [clojure.tools.logging :as log]
            [jsonista.core :as json]
            [reference-service.data.loader :as loader]
            [manifold.stream :as s])
  (:import
   (java.net URI)
   (io.socket.client IO Socket Ack)
   (io.socket.emitter Emitter$Listener)))

(def trades-topic
  "/trades")

(defonce client
  (atom {:socket nil
         :connected? false}))

(defmulti handle
  (fn [message]
    (:topic message)))

(defmethod handle "/trades"
  [{:keys [payload]}]
  (loader/save-trade (:jdbc-ds @client) payload))


(defn disconnect
  [client]
  (let [{:keys [socket connected?]} @client]
    (when (and socket
               connected?)
      (.disconnect ^Socket socket)
      (reset! client {:connected? false}))))

(defn publish
  [topic payload]
  (let [{:keys [socket connected?]} @client]
    (when (and socket
               connected?)
      (.emit ^Socket socket
             "publish"
             (to-array
              [(json/write-value-as-string
                {:topic (str "/" topic)
                 :payload payload
                 :type topic})])))))

(defn connect
  [jdbc-ds uri]
  (disconnect client)
  (log/infof "Connecting to websocket %s" uri)
  (let [socket (IO/socket uri)]
    (reset! client {:socket socket
                    :jdbc-ds jdbc-ds
                    :connected? false})
    (.on socket
         "connect"
         (reify Emitter$Listener
           (call [_ _args]
             (swap! client assoc :connected? true)
             (log/info "Websocket client connected"))))
    (.on socket
         "disconnect"
         (reify Emitter$Listener
           (call [_ _]
             (swap! client assoc :connected? false)
             (log/info "Websocket client disconnected"))))
    (.on socket
         "connect_error"
         (reify Emitter$Listener
           (call [_ args]
             (swap! client assoc :connected? false)
             (log/error (first args) "Websocket client disconnected"))))
    (.on socket
         "publish"
         (reify Emitter$Listener
           (call [_ args]
             (try
               (let [msg (json/read-value (.toString (first args))
                                          json/keyword-keys-object-mapper)]
                 (if (= "System" (:from msg))
                   (log/info "System message received " msg)
                   (handle msg)))
               (catch Exception e
                 (log/error e "Exception handling incoming message"))))))
    (.connect socket)
    (log/info "Will subscribe to /trades")
    (.emit socket "subscribe" (into-array Object [trades-topic]))
    socket))

(defn create-client
  [jdbc-ds uri]
  (connect jdbc-ds uri)
  client)

(comment
  (def sock (connect nil "http://localhost:18086"))
  (.emit ^Socket sock
         "publish"
         (to-array [(json/write-value-as-string
                     {:topic "/prices"
                      :payload {:ticker "AAPL"
                                :price 100}
                      :type "Price"})]))
  #_1)
