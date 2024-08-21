(ns price-service.price-service
  (:gen-class)
  (:require [next.jdbc.connection :as connection]
            [clojure.tools.logging :as log]
            [price-service.data.loader :as loader]
            [price-service.web.server :as server])
  (:import
   (com.zaxxer.hikari HikariDataSource)))

(defn try-connection
  [jdbc-url]
  (reduce (fn [_ _]
            (try
              (let [c (connection/->pool HikariDataSource
                                         {:jdbcUrl jdbc-url
                                          :maxLifetime 60000})]
                (reduced c))
              (catch Exception e
                (log/error e "Failed to connect to database. Will wait and retry.")
                (Thread/sleep 5000)
                nil)))
          nil
          (range 3)))

(defn -main
  [& _args]
  (log/info "Starting price-service.")
  (Thread/setDefaultUncaughtExceptionHandler
   (reify Thread$UncaughtExceptionHandler
     (uncaughtException
       [_ t e]
       (log/error e "Uncaught exception in thread" t)
       (throw e))))
  (let [jdbc-url (connection/jdbc-url
                  {:dbtype "postgresql"
                   :dbname "traderX"
                   :host "xtdb"
                   :port 5432
                   :useSSL false})
        jdbc-ds (try-connection jdbc-url)]
    (loader/populate-stocks jdbc-ds)
    (server/start 18085 jdbc-ds)

    (.addShutdownHook
     (Runtime/getRuntime)
     (Thread.
      (fn []
        (log/info "Shutting down price-service.")
        (.close ^java.io.Closeable jdbc-ds)
        (server/stop)))))
  #_1)

(comment
  (-main)

  #_1)
