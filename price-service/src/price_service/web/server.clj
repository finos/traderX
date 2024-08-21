(ns price-service.web.server
  (:require [aleph.http :as http]
            [aleph.netty :as netty]
            [clojure.tools.logging :as log]
            [muuntaja.core :as m]
            [reitit.core :as r]
            [reitit.ring :as ring]
            [reitit.ring.coercion :as coercion]
            [reitit.ring.middleware.muuntaja :as muuntaja]
            [reitit.ring.middleware.parameters :as parameters]
            [price-service.web.routes :as routes]
            [price-service.web.middleware :as mw]))

(defonce server
  (atom nil))

(def middleware
  {:reitit.middleware/registry
   {:parameters parameters/parameters-middleware
    :format-negotiate muuntaja/format-negotiate-middleware
    :format-response muuntaja/format-response-middleware
    :format-request muuntaja/format-request-middleware
    :coerce-response coercion/coerce-response-middleware
    :coerce-request coercion/coerce-request-middleware
    :cors mw/cors-middleware
    :exceptions mw/wrap-exceptions}
   :data {:muuntaja m/instance}})

(defn start
  [port jdbc-ds]
  (let [handler
        (ring/ring-handler
         (ring/router
          (routes/routes jdbc-ds)
          middleware))]
    (http/start-server
     handler
     {:port port})))

(defn stop
  []
  (when-let [server @server]
    (log/info "Stopping server.")
    (.close ^java.io.Closeable server)
    (netty/wait-for-close server)
    (reset! server nil)))
