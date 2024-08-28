(ns reference-service.data.loader
  (:require
   [clojure.data.csv :as csv]
   [clojure.java.io :as io]
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [medley.core :as medley]
   [next.jdbc :as jdbc]
   [next.jdbc.connection :as connection]
   [next.jdbc.sql :as sql]
   [next.jdbc.prepare :as p]
   [clojure.math :as math])
  (:import
   (com.zaxxer.hikari HikariDataSource)))

(def csv
  "./resources/s-and-p-500-companies.csv")

(def insert-stocks
  "insert into stocks
     (_id, security, sec_filings, gics_sector,
      gics_sub_industry, headquarters, first_added,
      cik, founded)
    values
     (?,?,?,?,?,?,?,?,?)")

(def insert-prices
  "insert into stock_prices
     (_id, price)
    values
     (?,?)")

(def insert-trade
  "insert into trades
     (_id, ticker, account_id, price, quantity, side)
   values
     (?,?,?,?,?,?)")

(def select-stocks
  "select _id as ticker, security as company from stocks")

(def select-stock-prices
  "select _id as ticker, price
   from stock_prices
   where _id in ")

(def update-prices
  "update stock_prices
   set price = ?
   where _id = ?")

(defonce stocks
  (atom {}))

(defn cache-stocks
  "Indexes stocks by ticker"
  [stockz]
  (reset! stocks
          (->>  stockz
                (map (fn [stock]
                       (-> stock
                           (assoc :companyName (:company stock))
                           (dissoc :company))))
                (medley/index-by :ticker))))

(defn read-stocks
  [connection-like]
  (let [stocks
        (sql/query connection-like
                   [select-stocks])]
    (when (seq stocks)
      (cache-stocks stocks))))

(defn do-insert
  [jdbc-ds data]
  (with-open [conn (jdbc/get-connection jdbc-ds)
              stocks-ps (jdbc/prepare conn
                                      [insert-stocks])
              prices-ps (jdbc/prepare conn
                                      [insert-prices])]
    (jdbc/execute-batch! stocks-ps
                         (mapv
                          (fn [line]
                            (update line 7 #(Integer/parseInt %)))
                          data)
                         {:return-keys false
                          :return-generated-keys false})
    (jdbc/execute-batch! prices-ps
                         (mapv
                          (fn [line]
                            [(first line)
                             (rand-int 1000)])
                          data)
                         {:return-keys false
                          :return-generated-keys false})
    (read-stocks conn)))

(defn populate-stocks
  [jdbc-ds]
  (with-open [rdr (io/reader csv)]
    (let [data-lines (drop 1 (csv/read-csv rdr))
          input-stock-count (count data-lines)
          stocks (read-stocks jdbc-ds)]
      (if (= (count stocks) input-stock-count)
        (log/infof "Stocks already populated, there are %d stocks" (count stocks))
        (do
          (log/infof "Populating %d stocks and prices" input-stock-count)
          (do-insert jdbc-ds data-lines))))))

(defn get-stock
  [jdbc-ds ticker]
  (when (nil? @stocks)
    (read-stocks jdbc-ds))
  (get @stocks
       (when ticker
         (str/upper-case ticker))))

(defn get-all-stocks
  [jdbc-ds]
  (when (nil? @stocks)
    (read-stocks jdbc-ds))
  (vals @stocks))

(defn generate-new-price
  "Generates a new price for a stock, within +- 10% of the last price."
  [last-price]
  (let [delta (* (if (> 0.5 (rand)) 0.1 -0.1)
                 last-price)]
    (int (math/floor (+ last-price (rand-int delta))))))

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
                           tickers))
        _ (log/infof "prices %s" (str/join ", " (map pr-str prices)))
        new-prices (map #(update %
                                :price
                                generate-new-price)
                        prices)]
    (save-prices jdbc-ds new-prices)
    new-prices))

(defn save-trade
  [jdbc-ds trade]
  (log/infof "Saving trade %s" trade)
  (jdbc/execute-one! jdbc-ds
                     [insert-trade
                      (str (java.util.UUID/randomUUID))
                      (:security trade)
                      (:accountId trade)
                      (:unitPrice trade)
                      (:quantity trade)
                      (:side trade)]))
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
  (populate-stocks jdbc-ds)
  (with-open [rdr (io/reader csv)]
    (do-insert jdbc-ds (drop 1 (csv/read-csv rdr))))

  (def prices (sql/query jdbc-ds
                         ["select * from stock_prices where _id in (?,?)"
                          "AAPL" "IBM"]))
  (jdbc/execute! jdbc-ds
                 ["insert into stock_prices (price,_id) values (?,?),(?,?)"
                  101 "AAPL"
                  201 "IBM"])
  (with-open [con (jdbc/get-connection jdbc-ds)
              ps (jdbc/prepare con ["update stock_prices set price=? where _id=?"])]
    (p/set-parameters ps [(with-meta 301 {:pgtype "integer"}) "IBM"])
    ;; (.setInt ps 1 301)
    ;; (.setString ps 2 "IBM")
    (.addBatch ps)
    ;; (.addBatch ps)
    (p/set-parameters ps [(with-meta 201 {:pgtype "integer"}) "AAPL"])
    ;; (.setInt ps 1 201)
    ;; (.setString ps 2 "AAPL")
    (.addBatch ps)
    (.executeBatch ps))
  (def pricez (sql/query jdbc-ds
                         ["select _id as stock, price, _valid_from, _system_from from stock_prices where _id = ?
               order by _valid_from desc"
                          "AAPL" #_"IBM"]))

  (def stocks (cache-stocks (read-stocks jdbc-ds)))
  #_1)
;; => nil
