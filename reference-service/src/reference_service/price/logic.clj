(ns reference-service.price.logic
  (:require
   [clojure.math :as math]
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [manifold.stream :as s]
   [medley.core :as medley]
   [next.jdbc :as jdbc]
   [next.jdbc.connection :as connection]
   [next.jdbc.sql :as sql])
  (:import
   (com.zaxxer.hikari HikariDataSource)
   (java.time Instant LocalDateTime ZoneId)
   (java.time.format DateTimeFormatter)))

(def insert-prices
  "insert into stock_prices
     (_id, price)
    values
     (?,?)")

(def insert-trade
  "insert into trades
     (_id, security, account_id, price, quantity, side, state, _valid_from)
   values
     (?,?,?,?,?,?,?,?)")

(def insert-position
  "insert into positions
     (_id, account_id, security, quantity, value, trade, calculation, _valid_from)
   values
     (?,?,?,?,?,?,?,?)")

(def select-stock-prices
  "select _id as ticker, price
   from stock_prices
   where _id in ")

(def all-stock-prices
  "select _id as ticker, price
   from stock_prices")

(def account-prices
  "select sp._id as ticker, sp.price
   from stock_prices sp
   join positions p on sp._id = p.security
   where p.account_id = ?")

(def account-prices-at
  "select sp._id as ticker, sp.price
   from stock_prices for valid_time as of ? sp
   join positions p on sp._id = p.security
   where p.account_id = ?")

(def update-prices
  "update stock_prices
   set price = ?
   where _id = ?")

(def update-prices-at
  "update stock_prices
   set price = ?
   where _id = ?")

(def select-stocks
  "select _id as ticker
   from stocks")

(def select-points-in-time
  "select _valid_to as end, _valid_from as start
   from trades
   for all valid_time
   where account_id=?
   order by start, end nulls last")

(def trade-intervals
  "select _valid_to as end, _valid_from as start, security, account_id as accountId, state
   from trades
   for all valid_time
   where account_id=?
   order by start, end nulls last")

(def recent-prices
  (atom {}))

(def price-update-stream
  (atom nil))

(defn generate-new-price
  "Generates a new price for a stock, within +- 5% of the last price.
   If the new price is zero, it will recursively call itself until a non-zero price is generated."
  [last-price]
  (let [delta (* (if (> 0.5 (rand)) 0.05 -0.05)
                 last-price)
        new-price (math/floor
                   (+ last-price (rand-int delta)))
        non-zero-price (if (zero? new-price)
                         (+ 1 (rand-int 10))
                         new-price)]
    (int non-zero-price)))

(defn set-system-time
  [conn timestamp]
  (sql/query conn [(str "SET TRANSACTION READ WRITE, AT SYSTEM_TIME TIMESTAMP '"
                        timestamp "'")]))

(defn local-date
  [timestamp]
  (LocalDateTime/ofInstant
   (Instant/ofEpochMilli timestamp)
   (ZoneId/of "UTC")))

(defn populate-prices
  [jdbc-ds]
  (let [prices (sql/query jdbc-ds
                          [all-stock-prices])]
    (log/info (if (seq prices)
                "Prices had been populated"
                "Populating prices"))
    (if (seq prices)
      (reset! recent-prices
              (medley/index-by :ticker prices))
      (with-open [conn (jdbc/get-connection jdbc-ds {:read-only false})]
        (let [stocks (map :ticker
                          (sql/query conn
                                     [select-stocks]))
              year-ago (.minusDays (LocalDateTime/now) 365)
              prices (mapv
                      (fn [stock]
                        [stock
                         (rand-int 1000)])
                      stocks)
              insert-prices-statement (str "insert into stock_prices (_id, price) values "
                                           (str/join "," (repeat (count prices) "(?,?)")))]
          (set-system-time conn year-ago)
          (sql/query conn ["BEGIN"])
          (jdbc/execute! conn
                         (reduce
                          into
                          [insert-prices-statement]
                          prices))
          (sql/query conn ["COMMIT"])
          (run! (fn [offset]
                  (set-system-time conn
                                   (.plusDays year-ago offset))
                  (sql/query conn ["BEGIN"])
                  (run! (fn [[ticker price]]
                          (sql/query conn
                                     [update-prices-at
                                      (generate-new-price price)
                                      ticker]))
                        prices)
                  (sql/query conn ["COMMIT"]))
                (range 1 366))
          (reset! recent-prices
                  (medley/index-by :ticker
                                   (sql/query conn
                                              [all-stock-prices]))))))))

(defn save-prices
  [jdbc-ds prices]
  (with-open [conn (jdbc/get-connection jdbc-ds)]
    (jdbc/execute! conn ["BEGIN READ WRITE"])
    (doseq [{:keys [price ticker]} prices]
      (jdbc/execute! conn
                     [update-prices
                      price ticker]))
    (jdbc/execute! conn ["COMMIT"])))

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
                value]
         :or {posid (str (java.util.UUID/randomUUID))
              oldquantity 0
              value 0}} (first
                         (sql/query jdbc-ds
                                    [select-position
                                     accountId security]))
        new-quantity (+ oldquantity
                        (if (= side "Buy")
                          quantity
                          (- quantity)))
        new-value (+ value
                     (* unitPrice quantity
                        (if (= side "Sell") 1 -1)))
        calculation (format "(+ %d (* %d %d %d))"
                            value unitPrice quantity
                            (if (= "Sell" side) 1 -1))]
    [posid
     (long accountId)
     security
     (long new-quantity)
     (long new-value)
     id
     calculation]))

(defn save-trade
  [jdbc-ds {:keys [id security accountId
                   unitPrice quantity side
                   created updated]
            :as trade}]
  (with-open [conn (jdbc/get-connection jdbc-ds)]
    (let [trade-pending (local-date created)
          settled (local-date updated)
          position (conj (position-for jdbc-ds trade) settled)]
      (log/infof "Saving trade %s and position %s" (pr-str trade) (pr-str position))
      (sql/query conn ["BEGIN READ WRITE"])
      (jdbc/execute! conn [insert-trade
                           id
                           security
                           (long accountId)
                           (long unitPrice)
                           (long quantity)
                           side
                           "Pending"
                           trade-pending]
                     {:return-keys false})
      (sql/query conn ["COMMIT"])
      (sql/query conn ["BEGIN READ WRITE"])
      (jdbc/execute! conn ["update trades
                            for valid_time
                            from ? to null
                            set state = ?
                            where _id = ?"
                           settled
                           "Settled"
                           id])
      (jdbc/execute! conn (into
                           [insert-position]
                           position)
                     {:return-keys false})
      (sql/query conn ["COMMIT"]))))

(defn get-recent-prices
  [stocks]
  (mapv
   #(get @recent-prices %)
   stocks))

(def date-time-formatter
  (DateTimeFormatter/ofPattern "yyyy-MM-dd'T'HH:mm:ss'Z'"))

(defn parse-date-time
  [dt]
  (-> dt
      (str/replace #"\.\d\d\d" "")
      (LocalDateTime/parse date-time-formatter)))

(defn account-trades
  ([jdbc-ds account-id start end]
   (log/infof "Get account trades start %s end %s" start end)
   (sql/query jdbc-ds
              (if start
                ["select _id as id, security, quantity, side, price, state, _valid_from, _valid_to
                  from trades
                  for valid_time
                  from ? to ?
                  where account_id = ?"
                 (parse-date-time start)
                 (when-not (or (nil? end)
                               (= "null" end))
                   (parse-date-time end))
                 account-id]
                ["select _id as id, security, quantity, side, price, state, _valid_from, _valid_to
                  from trades
                  for valid_time all
                  where account_id = ?"
                 account-id]))))

(defn account-positions
  [jdbc-ds account-id start end]
  (log/infof "Get account positions start %s end %s" start end)
  (let [positions
        (sql/query jdbc-ds
                   (if start
                     ["select _id as id, security, trade, value, quantity, calculation, _valid_from, _valid_to
                       from positions
                       for valid_time
                       from ? to ?
                       where account_id = ?
                       order by security,
                                _valid_from desc,
                                _valid_to desc nulls last"
                      (parse-date-time start)
                      (when-not (or (nil? end)
                                    (= "null" end))
                        (parse-date-time end))
                      account-id]
                     ["select _id as id, security, trade, value, quantity, calculation, _valid_from, _valid_to
                       from positions
                       for valid_time all
                       where account_id = ?
                       order by security,
                                _valid_from desc,
                                _valid_to desc nulls first"
                      account-id]))]
    (->> positions
         (group-by :security)
         vals
         (map first)
         flatten)))

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

(defn get-recent-prices-for-account
  [jdbc-ds account-id]
  (sql/query jdbc-ds
             [account-prices
              account-id]))

(defn get-prices-for-account-at
  [jdbc-ds account-id for-date]
  (let [valid-at (parse-date-time for-date)]
    (sql/query jdbc-ds
               [account-prices-at
                valid-at
                account-id])))

(defn get-trade-points-in-time
  "Get all the different valid time points sorted. ALL (open end) not included."
  [jdbc-ds account-id]
  (let [start-ends (sql/query jdbc-ds
                              [select-points-in-time
                               account-id])
        points (sort
                (distinct
                 (mapcat
                  (fn [{:keys [start end]}]
                    (if end
                      [start end]
                      [start]))
                  start-ends)))]
    points))

(defn get-trade-intervals
  [jdbc-ds account-id]
  (sql/query jdbc-ds
             [trade-intervals
              account-id]))

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
  (map :security (account-positions jdbc-ds 22214 nil nil))
  (def prices (sql/query jdbc-ds
                         ["select * from stock_prices where _id in (?,?)"
                          "AAPL" "IBM"]))
  (get-trade-intervals jdbc-ds 52355)

  (generate-new-prices jdbc-ds)

  (generate-new-price 100)
  (sql/query jdbc-ds [select-points-in-time])
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

  #_1)
