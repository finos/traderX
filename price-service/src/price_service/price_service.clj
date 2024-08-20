(ns price-service.price-service
  (:gen-class)
  (:require [next.jdbc.types]
            [next.jdbc.date-time]
            [next.jdbc.sql :as sql]
            [next.jdbc.connection :as connection]
            [clojure.java.io :as io]
            [clojure.data.csv :as csv]
            [clojure.tools.logging :as log])
  (:import
   (java.time LocalDateTime)
   (com.zaxxer.hikari HikariDataSource)))

(def csv "../reference-data/data/s-and-p-500-companies.csv")

(def insert-stocks
  "insert into stocks
     (_id, security, sec_filings, gics_sector, gics_sub_industry, headquarters, first_added, cik, founded)
     values (?, ?, ?, ?, ?, ?, ?, ?, ?)")

(def stock-columns
  [:_id :security :sec_filings
   :gics_sector :gics_sub_industry
   :headquarters :first_added :cik
   :founded])

(def insert-stock-prices
  "insert into stock_prices
     (_id, ts, price)
     values (?, ?, ?")

(def stock-price-columns
  [:_id :ts :price])

(defn do-insert
  [jdbc-ds data]
  (let [timestamp (LocalDateTime/now)]
    (sql/insert-multi! jdbc-ds
                         :stocks
                         stock-columns
                         (mapv
                          (fn [line]
                            (update line 7 #(Integer/parseInt %)))
                          data)
                         {:batch true
                          :return-keys false})
    (sql/insert-multi! jdbc-ds
                       :stock_prices
                       stock-price-columns
                       (mapv
                        (fn [line]
                          [(first line)
                           timestamp
                           (rand-int 1000)])
                        data)
                       {:batch true
                        :return-keys false}))
  ;; [(jdbc-types/as-varchar (first line))
  ;;  (jdbc-types/as-timestamp timestamp)
  ;;  (jdbc-types/as-integer (rand-int 1000))]
  ;; doesn't cope with creating preped statement from vectors
  #_(jdbc/execute-batch! conn
                         (into [insert-stocks]
                               (mapv
                                (fn [line]
                                  (update line 7 #(Integer/parseInt %)))
                                data-lines))
                         {:return-keys false}))

(defn populate-stocks
  [jdbc-ds csv]
  (with-open [rdr (io/reader csv)]
    (let [data-lines (drop 1 (csv/read-csv rdr))
          input-stock-count (count data-lines)
          stocks-count (:cnt (sql/query jdbc-ds ["select count(*) as cnt from stocks"]))]
      (if (= stocks-count input-stock-count)
        (log/infof "Stocks already populated, there are %d stocks" stocks-count)
        (do
          (log/infof "Populating %d stocks and prices" input-stock-count)
          (do-insert jdbc-ds data-lines))))))

(defn -main
  [& args]
  (let [jdbc-url (connection/jdbc-url
                  {:dbtype "postgresql"
                   :dbname "traderX"
                   :host "localhost"
                   :port 18099
                   :useSSL false})
        jdbc-ds (connection/->pool HikariDataSource
                                   {:jdbcUrl jdbc-url
                                    :maxLifetime 60000})]
    (populate-stocks jdbc-ds csv))

  #_1)

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

  ;; this runs against postgres:15.2 - works OK (just need to create the table first)
  ;; create table stock_prices (_id text, ts timestamp, price integer);
  (let [csv "../reference-data/data/s-and-p-500-companies.csv"
        jdbc-url (connection/jdbc-url
                  {:dbtype "postgresql"
                   :dbname "postgres"
                   :host "localhost"
                   :port 5432
                   :useSSL false})
        jdbc-ds (connection/->pool HikariDataSource
                                   {:jdbcUrl jdbc-url
                                    :username "postgres"
                                    :maxLifetime 60000})]
    (with-open [rdr (io/reader csv)]
      (do-insert jdbc-ds (drop 1 (csv/read-csv rdr)))))

  #_1)
