(ns price-service.price-service
  (:gen-class)
  (:require [next.jdbc.connection :as connection]
            [clojure.tools.logging :as log]
            [price-service.data.loader :as loader]
            [price-service.web.server :as server])
  (:import
   (com.zaxxer.hikari HikariDataSource)))

;; TODO - replace reference-data node app with this - in nginx conf / docker-compose
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
    (loader/populate-stocks jdbc-ds)
    (server/start 8666 jdbc-ds)

    (.addShutdownHook
     (Runtime/getRuntime)
     (Thread.
      (fn []
        (log/info "Shutting down price-service.")
        (.close ^java.io.Closeable jdbc-ds)
        (server/stop)))))
  (Thread/setDefaultUncaughtExceptionHandler
   (reify Thread$UncaughtExceptionHandler
     (uncaughtException
       [_ t e]
       (log/error e "Uncaught exception in thread" t))))
  #_1)

(comment
  (-main)

  #_1)
