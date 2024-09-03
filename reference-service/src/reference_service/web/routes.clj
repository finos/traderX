(ns reference-service.web.routes
  (:require
   [clojure.tools.logging :as log]
   [jsonista.core :as json]
   [reitit.core :as r]
   [reference-service.data.loader :as loader]
   [reference-service.price.logic :as prices]
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
   ["price/:ticker"
    {:allow-methods [:get]
     :get
     {:handler
      (fn [{:keys [path-params]}]
        (let [ticker (:ticker path-params)]
          (log/info "Get price for stock:" ticker)
          (if-let [price (first (prices/get-recent-prices [ticker]))]
            (-> price
                to-json
                response/ok
                (response/header "Content-Type" "application/json"))
            (response/not-found (str "Price not found for stock: " ticker)))))}}]
   ["prices/:account-id"
    {:allow-methods [:get]
     :get
     {:handler
      (fn [{:keys [path-params]}]
        (let [account-id (try (Integer/parseInt (:account-id path-params))
                              (catch Exception _ "-666"))]
          (log/info "Get prices for stocks in account:" (:account-id path-params))
          (if-let [prices (seq (prices/get-recent-prices-for-account jdbc-ds account-id))]
            (-> prices
                to-json
                response/ok
                (response/header "Content-Type" "application/json"))
            (response/not-found (str "Prices not found for stocks in account: " (:account-id path-params))))))}}]
   ["stocks"
    [""
     {:allow-methods [:get]
      :get
      {:handler
       (fn [_]
         (log/info "Get all stocks.")
         (-> (loader/get-all-stocks jdbc-ds)
             to-json
             response/ok
             (response/header "Content-Type" "application/json")))}}]
    ["/:ticker"
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [ticker (:ticker path-params)]
           (log/info "Get stock:" ticker)
           (if-let [stock (loader/get-stock jdbc-ds ticker)]
             (-> stock
                 to-json
                 response/ok
                 (response/header "Content-Type" "application/json"))
             (response/not-found (str "Stock not found: " ticker)))))}}]]])

(comment
  (def router (r/router (routes nil)))
  (r/match-by-path router "/")
  (r/match-by-path router "/health")
  (r/match-by-path router "/stocks")
  (r/match-by-path router "/stocks/x")

  #_1)
