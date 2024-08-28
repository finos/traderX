(ns reference-service.reference-service
  (:gen-class)
  (:require [next.jdbc.connection :as connection]
            [clojure.tools.logging :as log]
            [clojure.java.io :as io]
            [aero.core :as aero]
            [reference-service.data.loader :as loader]
            [reference-service.web.server :as server]
            [reference-service.web.socket :as websocket])
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

(defn read-config
  []
  (let [cfg (aero/read-config
             (io/resource "application.edn"))]
    (-> cfg
        (update :xtdb-port #(Integer/parseInt %))
        (update :web-port #(Integer/parseInt %))
        (update :price-update-interval-ms #(Integer/parseInt %)))))

(defn -main
  [& _args]
  (log/info "Starting reference-service.")
  (Thread/setDefaultUncaughtExceptionHandler
   (reify Thread$UncaughtExceptionHandler
     (uncaughtException
       [_ t e]
       (log/error e "Uncaught exception in thread" t)
       (throw e))))

  (let [{:keys [xtdb-port
                xtdb-host
                web-port
                price-update-interval-ms
                trade-feed-address]} (read-config)

        jdbc-url (connection/jdbc-url
                  {:dbtype "postgresql"
                   :dbname "traderX"
                   :host xtdb-host
                   :port xtdb-port
                   :useSSL false})
        jdbc-ds (try-connection jdbc-url)]
    (loader/populate-stocks jdbc-ds)
    (server/start web-port jdbc-ds)
    (websocket/create-client jdbc-ds trade-feed-address price-update-interval-ms)

    (.addShutdownHook
     (Runtime/getRuntime)
     (Thread.
      (fn []
        (log/info "Shutting down reference-service.")
        (.close ^java.io.Closeable jdbc-ds)
        (server/stop)
        (websocket/stop-client)))))
  #_1)

(comment
  (-main)

  #_1)
