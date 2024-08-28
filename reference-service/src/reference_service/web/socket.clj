(ns reference-service.web.socket
  (:require
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [jsonista.core :as json]
   [manifold.stream :as s]
   [medley.core :as medley]
   [reference-service.data.loader :as loader])
  (:import
   (io.socket.client IO Socket)
   (io.socket.emitter Emitter$Listener)))

(def trades-topic
  "/trades")
(def prices-topic
  "/prices")
(def market-value-topic
  "/marketValue")

(defonce client
  (atom {:socket nil
         :jdbc-ds nil
         :price-update-stream nil
         :price-update-interval-ms nil
         :connected? false}))

(defn start-price-update-stream
  [stocks]
  (when-let [previous (:price-update-stream @client)]
    (s/close! previous))
  (let [price-stream (s/periodically
                      (:price-update-interval-ms @client)
                      0 ;; start immediately
                      (fn []
                        (loader/get-prices
                         (:jdbc-ds @client)
                         stocks)))]
    (swap! client assoc :price-update-stream price-stream)
    price-stream))

(defn publish-market-value
  [payload]
  (let [{:keys [socket connected?]} @client
        message {"topic" market-value-topic
                 "payload" (mapv #(medley/map-keys name %)
                                 payload)
                 "type" "MarketValue"}]
    (when (and socket
               connected?)
      (.emit ^Socket socket
             "publish"
             (into-array
              Object
              [message])))))

(defmulti handle
  (fn [message]
    (:topic message)))

(defmethod handle trades-topic
  [{:keys [payload]}]
  (loader/save-trade (:jdbc-ds @client) payload))

(defmethod handle prices-topic
  [{:keys [payload]}]
  (log/infof "received stock price update subscription for %s" (str/join ", " payload))
  (when (seq payload)
    (let [price-stream (start-price-update-stream payload)]
      (s/consume (fn [prices]
                   (publish-market-value prices))
                 price-stream))))

(defn disconnect
  [client]
  (let [{:keys [socket connected? price-update-stream]} @client]
    (when price-update-stream
      (s/close! price-update-stream))
    (when (and socket
               connected?)
      (.disconnect ^Socket socket)
      (reset! client {:connected? false}))))

(defn connect
  [jdbc-ds uri price-update-interval-ms]
  (disconnect client)
  (log/infof "Connecting to websocket %s" uri)
  (let [socket (IO/socket uri)]
    (reset! client {:socket socket
                    :jdbc-ds jdbc-ds
                    :connected? false
                    :price-update-interval-ms price-update-interval-ms})
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
    (log/info "Will subscribe to /trades and /prices topics.")
    (.emit socket "subscribe" (into-array Object [trades-topic]))
    (.emit socket "subscribe" (into-array Object [prices-topic]))
    socket))

(defn create-client
  [jdbc-ds uri price-update-interval-ms]
  (connect jdbc-ds uri price-update-interval-ms)
  client)

(defn stop-client
  []
  (disconnect client))

(comment
  (def sock (connect nil "http://localhost:18086" 2000))
  (.emit ^Socket sock
         "publish"
         (to-array [{:topic "/marketValue"
                     :payload [{:ticker "AAPL"
                                :price 100}]
                     :type "Price"}]))
  (mapv #(medley/map-keys name %)
        [{:ticker "AAPL"
          :price 100}])
  #_1)
