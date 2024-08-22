(ns reference-service.web.routes
  (:require
   [clojure.tools.logging :as log]
   [jsonista.core :as json]
   [reitit.core :as r]
   [reference-service.data.loader :as loader]
   [ring.util.http-response :as response]))

(defn to-json
  [data]
  (json/write-value-as-string data))

(def default-mw [:parameters
                 :format-negotiate
                 :format-response
                 :format-request
                 :cors
                 :exceptions
                 :coerce-response
                 :coerce-request])

(defn routes
  [jdbc-ds]
  ["/"
   {:middleware default-mw}
   ["health"
    {:allow-methods [:get]
     :get
     {:handler
      (fn [_]
        (log/info "Health check.")
        (response/ok "OK"))}}]
   ["stocks"
    [""
     {:allow-methods [:get]
      :get
      {:handler
       (fn [_]
         (log/info "Get all stocks.")
         (response/header
          (response/ok (to-json (loader/get-all-stocks jdbc-ds)))
          "Content-Type" "application/json"))}}]
    ["/:ticker"
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [ticker (:ticker path-params)]
           (log/info "Get stock:" ticker)
           (if-let [stock (loader/get-stock jdbc-ds ticker)]
             (response/header
              (response/ok (to-json stock))
              "Content-Type" "application/json")
             (response/not-found (str "Stock not found: " ticker)))))}}]]])

(comment
  (def router (r/router (routes nil)))
  (r/match-by-path router "/")
  (r/match-by-path router "/health")
  (r/match-by-path router "/stocks")
  (r/match-by-path router "/stocks/x")

  #_1)
