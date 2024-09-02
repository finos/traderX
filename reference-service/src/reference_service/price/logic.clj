(ns reference-service.price.logic
  (:require
   [clojure.math :as math]
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [manifold.stream :as s]
   [medley.core :as medley]
   [next.jdbc :as jdbc]
   [next.jdbc.connection :as connection]
   [next.jdbc.prepare :as p]
   [next.jdbc.sql :as sql])
  (:import
   (com.zaxxer.hikari HikariDataSource)
   (java.time Instant LocalDateTime ZoneId)))

(def insert-prices
  "insert into stock_prices
     (_id, price)
    values
     (?,?)")

(def insert-trade
  "insert into trades
     (_id, security, account_id, price, quantity, side)
   values
     (?,?,?,?,?,?)")

(def insert-position
  "insert into positions
     (_id, account_id, security, quantity, value, trade, calculation)
   values
     (?,?,?,?,?,?,?)")

(def select-stock-prices
  "select _id as ticker, price
   from stock_prices
   where _id in ")

(def all-stock-prices
  "select _id as ticker, price
   from stock_prices")

(def update-prices
  "update stock_prices
   set price = ?
   where _id = ?")

(def select-stocks
  "select _id as ticker
   from stocks")

(def recent-prices
  (atom {}))

(def price-update-stream
  (atom nil))

(defn populate-prices
  [jdbc-ds]
  ;; TODO also populate initial trades and positions
  (let [prices (sql/query jdbc-ds
                          [all-stock-prices])]
    (if (seq prices)
      (reset! recent-prices
              (medley/index-by :ticker prices))
      (with-open [conn (jdbc/get-connection jdbc-ds)
                  prices-ps (jdbc/prepare conn
                                          [insert-prices])]
        (let [stocks (map :ticker
                          (sql/query conn
                                     [select-stocks]))
              prices (mapv
                      (fn [stock]
                        [stock
                         (rand-int 1000)])
                      stocks)
              cache-prices (map (fn [[ticker price]]
                                  {:ticker ticker
                                   :price price})
                                prices) ]
          (reset! recent-prices
                  (medley/index-by :ticker cache-prices))
          (jdbc/execute-batch! prices-ps
                               prices
                               {:return-keys false
                                :return-generated-keys false}))))))

(defn generate-new-price
  "Generates a new price for a stock, within +- 5% of the last price.
   If the new price is zero, it will recursively call itself until a non-zero price is generated."
  [last-price]
  (let [delta (* (if (> 0.5 (rand)) 0.05 -0.05)
                 last-price)
        new-price (int (math/floor
                        (+ last-price (rand-int delta))))]
    (if (zero? new-price)
      (+ 1 (rand-int 10))
      new-price)))

(defn save-prices
  [jdbc-ds prices]
  (with-open [conn (jdbc/get-connection jdbc-ds)
              ps (jdbc/prepare conn
                               [update-prices])]
    (doseq [price prices]
      (p/set-parameters ps [(-> price :price int)
                            (-> price :ticker str)])
      (.addBatch ps))
    (.executeBatch ps)))

(defn get-prices
  [jdbc-ds tickers]
  (let [params (str "(" (str/join ", " (repeat (count tickers) "?")) ")")
        prices (sql/query jdbc-ds
                          (into
                           [(str select-stock-prices params)]
                           tickers))]
    prices))

(defn generate-new-prices
  [jdbc-ds]
  (let [prices (if (seq @recent-prices)
                 (vals @recent-prices)
                 (sql/query jdbc-ds
                            [all-stock-prices]))
        new-prices (map #(update %
                                 :price
                                 generate-new-price)
                        prices)]
    (log/info "Generated new prices")
    (reset! recent-prices
            (medley/index-by :ticker new-prices))
    new-prices))

(def select-position
  "select _id as posid, quantity as oldquantity, value
   from positions
   where account_id = ? and security = ?")

(defn position-for
  [jdbc-ds {:keys [security id accountId quantity unitPrice side]}]
  (let [{:keys [posid
                oldquantity
                value]} (first
                         (sql/query jdbc-ds
                                    [select-position
                                     accountId security]))]
    [(or posid
         (str (java.util.UUID/randomUUID)))
     (Integer/parseInt accountId)
     security
     (+ (or oldquantity 0)
        (if (= side "Buy")
          quantity
          (- quantity)))
     (+ (or value 0)
        (* unitPrice quantity
           (if (= side "Sell") 1 -1)))
     id
     ;; FIXME - find a better way of expressing this - quoting doesn't do what i want
     (pr-str '(+ ~(or value 0)
                 (* ~unitPrice ~quantity
                    (if (= ~side "Sell") 1 -1))))]))

(defn save-trades
  [jdbc-ds trades]
  (log/infof "Saving trade %s" trades)
  (with-open [conn (jdbc/get-connection jdbc-ds)
              trade-ps (jdbc/prepare conn
                                     [insert-trade])
              position-ps (jdbc/prepare conn
                                        [insert-position])]
    (doseq [trade trades]
      (p/set-parameters trade-ps [(:id trade)
                                  (:security trade)
                                  (Integer/parseInt (:accountId trade))
                                  (Integer/parseInt (:unitPrice trade))
                                  (Integer/parseInt (:quantity trade))
                                  (:side trade)])
      (.addBatch trade-ps)
      (let [position (position-for jdbc-ds trade)]
        (log/infof "Saving position %s" position)

        (p/set-parameters position-ps position)
        (.addBatch position-ps)))
    (.executeBatch trade-ps)
    (.executeBatch position-ps)))

(defn get-recent-prices
  [stocks]
  (mapv
   #(get @recent-prices %)
   stocks))

(defn account-trades
  [jdbc-ds account-id]
  (sql/query jdbc-ds
             ["select * from trades where account_id = ?"
              account-id]))

(defn account-positions
  [jdbc-ds account-id]
  (sql/query jdbc-ds
             ["select * from positions where account_id = ?"
              account-id]))

(defn start-price-update-stream
  [jdbc-ds price-update-interval-ms]
  (let [price-stream (s/periodically
                      price-update-interval-ms
                      0
                      (fn []
                        (generate-new-prices jdbc-ds)))]
    (when-let [previous @price-update-stream]
      (s/close! previous))
    (reset! price-update-stream price-stream)
    (s/consume (fn [new-prices]
                 (save-prices jdbc-ds new-prices))
               price-stream)))

(defn stop-price-update-stream
  []
  (when-let [previous @price-update-stream]
    (s/close! previous)
    (reset! price-update-stream nil)))

(comment
  (def jdbc-url (connection/jdbc-url
                 {:dbtype "postgresql"
                  :dbname "traderX"
                  :host "localhost"
                  :port 18099
                  :useSSL false}))
  (def jdbc-ds (connection/->pool HikariDataSource
                                  {:jdbcUrl jdbc-url
                                   :maxLifetime 60000}))
  (map :security (account-positions jdbc-ds 22214))
  (def prices (sql/query jdbc-ds
                         ["select * from stock_prices where _id in (?,?)"
                          "AAPL" "IBM"]))
  (populate-prices jdbc-ds)
  (jdbc/execute! jdbc-ds
                 ["insert into stock_prices (price,_id) values (?,?),(?,?)"
                  101 "AAPL"
                  201 "IBM"])

  (def pricez (sql/query jdbc-ds
                         ["select _id as stock, price, _valid_from, _system_from from stock_prices where _id = ?
               order by _valid_from desc"
                          "AAPL" #_"IBM"]))

  (LocalDateTime/ofInstant (Instant/ofEpochMilli 6477227720)
                           (ZoneId/of "UTC"))

  (def prices (sql/query jdbc-ds
                         [all-stock-prices]))
  (defn populate-prices
    [jdbc-ds]
    (let []
      (if (seq prices)
        (reset! recent-prices
                (medley/index-by :ticker prices))
        (with-open [conn (jdbc/get-connection jdbc-ds)
                    prices-ps (jdbc/prepare conn
                                            [insert-prices])]
          (let [stocks (map :ticker
                            (sql/query conn
                                       [select-stocks]))
                prices (mapv
                        (fn [stock]
                          [stock
                           (rand-int 1000)])
                        stocks)]
            (reset! recent-prices
                    (medley/index-by :ticker prices))
            (jdbc/execute-batch! prices-ps
                                 prices
                                 {:return-keys false
                                  :return-generated-keys false}))))))
  #_1)
