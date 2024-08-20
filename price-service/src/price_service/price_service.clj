(ns price-service.price-service
  (:gen-class)
  (:require [next.jdbc :as jdbc]
            [next.jdbc.sql :as sql]
            [next.jdbc.connection :as connection]
            [clojure.java.io :as io]
            [clojure.data.csv :as csv]
            [clojure.string :as str]
            [clojure.tools.logging :as log])
  (:import
   (com.zaxxer.hikari HikariDataSource)))

(def csv "../reference-data/data/s-and-p-500-companies.csv")

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
    values (?,?)")

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
                          :return-generated-keys false})))

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

  #_1)
