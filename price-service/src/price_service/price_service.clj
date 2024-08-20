(ns price-service.price-service
  (:gen-class)
  (:require [next.jdbc.connection :as connection]
            [clojure.tools.logging :as log]
            [price-service.data.loader :as loader])
  (:import
   (com.zaxxer.hikari HikariDataSource)))

;; TODO - add namespace with server and replace reference-data node app with this
(defn -main
  [& _args]
  (log/info "Starting price-service.")
  (let [jdbc-url (connection/jdbc-url
                  {:dbtype "postgresql"
                   :dbname "traderX"
                   :host "localhost"
                   :port 18099
                   :useSSL false})
        jdbc-ds (connection/->pool HikariDataSource
                                   {:jdbcUrl jdbc-url
                                    :maxLifetime 60000})]
    (loader/populate-stocks jdbc-ds))

  #_1)
