(ns price-service.data.loader
  (:require
   [clojure.data.csv :as csv]
   [clojure.java.io :as io]
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [medley.core :as medley]
   [next.jdbc :as jdbc]
   [next.jdbc.connection :as connection]
   [next.jdbc.sql :as sql])
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

(def select-stocks
  "select _id as ticker, security as company from stocks")

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
  (with-open [rdr (io/reader csv)]
    (do-insert jdbc-ds (drop 1 (csv/read-csv rdr))))

  (def stocks (cache-stocks (read-stocks jdbc-ds)))
  #_1)
;; => nil
