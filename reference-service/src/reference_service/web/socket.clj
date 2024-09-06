(ns reference-service.web.socket
  (:require
   [clojure.tools.logging :as log]
   [jsonista.core :as json]
   [manifold.stream :as s]
   [medley.core :as medley]
   [reference-service.price.logic :as prices])
  (:import
   (io.socket.client IO Socket)
   (io.socket.emitter Emitter$Listener)))

(def trades-topic
  "/trades")
(defn account-prices-topic
  [account-id]
  (str "/accounts/" account-id "/prices"))
(def account-topic
  "/account")
(defn account-trades-topic
  [account-id]
  (str "/accounts/" account-id "/trades"))

(defonce client
  (atom {:socket nil
         :jdbc-ds nil
         :price-update-stream nil
         :price-update-interval-ms nil
         :connected? false}))

(defonce account
  (atom {:id nil
         :trades []
         :positions []}))

(defn start-price-update-stream
  []
  (when-let [previous (:price-update-stream @client)]
    (s/close! previous))
  (let [price-stream (s/periodically
                      30000
                      0 ;; start immediately
                      (fn []
                        (log/info "Sending market prices for " (:securities @account))
                        (prices/get-recent-prices
                         (:securities @account))))]
    (swap! client assoc :price-update-stream price-stream)
    price-stream))

(defn publish-market-value
  [payload]
  (if (seq payload)
    (let [{:keys [socket connected?]} @client
          message {"topic" (account-prices-topic (:id @account))
                   "payload" (mapv #(medley/map-keys name %)
                                   payload)
                   "type" "MarketValue"}]
      (when (and socket
                 connected?)
        (.emit ^Socket socket
               "publish"
               (into-array
                Object
                [message]))))
    (log/info "No market value to publish, skipping")))

(defn match-topic
  [{:keys [topic]}]
  (cond
    (= trades-topic topic) :trades-topic
    (= account-topic topic) :account-topic
    (re-find (re-matcher #"/accounts/\d+/trades" topic)) :account-trades-topic))

(defmulti handle match-topic)

(defmethod handle :account-topic
  [{:keys [payload]}]
  ;; TODO think if we should have multiple accounts and publish prices to all subscribed
  ;; we'd have to watch unsubscriptions too - so we remove those accounts from stream
  (log/infof "current account %d" payload)
  (let [trades (prices/account-trades (:jdbc-ds @client) payload)
        positions (prices/account-positions (:jdbc-ds @client) payload)
        securities (set (map :security trades))]
    (log/infof "Account positions %s" positions)
    (reset! account {:id payload
                     :trades trades
                     :securities securities
                     :positions positions})
    (log/infof "Will publish prices for: %s" securities)
    (publish-market-value (prices/get-recent-prices securities)))
  (let [price-stream (start-price-update-stream)]
    (s/consume publish-market-value
               price-stream))
  (.emit ^Socket (:socket @client)
         "subscribe"
         (into-array Object [(account-trades-topic payload)])))

(defmethod handle :account-trades-topic
  [{:keys [payload]}]
  (log/infof "Received account trades subscription for %s" (pr-str payload))
  (swap! account update :trades into [payload])
  (swap! account update :securities into [(:security payload)])
  (prices/save-trade (:jdbc-ds @client) payload)
  (publish-market-value (prices/get-recent-prices [(:security payload)])))

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
    (.on socket
         "unsubscribe"
         (reify Emitter$Listener
           (call [_ args]
             (log/info "Unsubscribed from topic" (pr-str args)))))
    (.connect socket)
    (log/info "Will subscribe to /account topic.")
    (.emit socket "subscribe" (into-array Object [account-topic]))
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
  (case (re-find (re-matcher #"/accounts*" "/accounts/123/trades"))
    "/accounts" 1)
  (re-find (re-matcher #"/accounts/\d+/trades" "/accounts/123/trades"))
  #_1)
