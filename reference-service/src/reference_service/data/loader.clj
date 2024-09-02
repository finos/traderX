(ns reference-service.data.loader
  (:require
   [clojure.data.csv :as csv]
   [clojure.java.io :as io]
   [clojure.string :as str]
   [clojure.tools.logging :as log]
   [medley.core :as medley]
   [next.jdbc :as jdbc]
   [next.jdbc.connection :as connection]
   [next.jdbc.prepare :as p]
   [next.jdbc.sql :as sql]
   [reference-service.price.logic :as prices])
  (:import
   (java.util UUID)
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
                                      [insert-stocks])]
    (jdbc/execute-batch! stocks-ps
                         (mapv
                          (fn [line]
                            (update line 7 #(Integer/parseInt %)))
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

(def insert-account
  "insert into accounts
     (_id, name)
    values
     (?,?)")

(def account-seed
  [[22214 "Test Account 20"]
   [11413 "Private Clients Fund TTXX"]
   [42422 "Algo Execution Partners"]
   [52355 "Big Corporate Fund"]
   [62654 "Hedge Fund TXY1"]
   [10031 "Internal Trading Book"]
   [44044 "Trading Account 1"]])

(def trade-seed
  [["TRADE-22214-AABBCC" "IBM" 22214  123 100 "Buy"]
   ["TRADE-22214-DDEEFF" "MS" 22214  88 1000 "Buy"]
   ["TRADE-22214-GGHHII" "C" 22214  321 2000 "Buy"]
   ["TRADE-52355-AABBCC" "BAC" 52355  20 2400 "Buy"]])

(def position-seed
  [[(str (UUID/randomUUID)) 22214 "MS" 1000 -88000 "TRADE-22214-DDEEFF" "(* 1000 88 -1)"]
   [(str (UUID/randomUUID)) 22214 "IBM" 100 -12300 "TRADE-22214-AABBCC" "(* 100 123 -1)"]
   [(str (UUID/randomUUID)) 22214 "C" 2000 -642000 "TRADE-22214-GGHHII" "(* 2000 321 -1)"]
   [(str (UUID/randomUUID)) 52355 "BAC" 2400 -48000 "TRADE-52355-AABBCC" "(* 2400 20 -1)"]])

(defn seed
  [jdbc-ds]
  (if (-> (sql/query jdbc-ds
                     ["select count(*) as cnt from accounts"])
          first
          :cnt
          zero?)
    (with-open [conn (jdbc/get-connection jdbc-ds)
                account-ps (jdbc/prepare conn
                                         [insert-account])
                trade-ps (jdbc/prepare conn
                                       [prices/insert-trade])
                position-ps (jdbc/prepare conn
                                          [prices/insert-position])]
      (log/info "Seeding database")
      (doseq [account account-seed]
        (p/set-parameters account-ps account)
        (.addBatch account-ps))
      (.executeBatch account-ps)
      (doseq [trade trade-seed]
        (p/set-parameters trade-ps trade)
        (.addBatch trade-ps))
      (.executeBatch trade-ps)
      (doseq [position position-seed]
        (p/set-parameters position-ps position)
        (.addBatch position-ps))
      (.executeBatch position-ps))
    (log/info "Database had already been seeded")))

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
  (seed jdbc-ds)
  (with-open [rdr (io/reader csv)]
    (do-insert jdbc-ds (drop 1 (csv/read-csv rdr))))

  (def stocks (cache-stocks (read-stocks jdbc-ds)))
  #_1)
