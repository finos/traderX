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

(defn get-account-id
  [path-params]
  (Integer/parseInt (:account-id path-params)))

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
    [""
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)]
           (log/info "Get prices for stocks in account:" (:account-id path-params))
           (if-let [prices (seq (prices/get-recent-prices-for-account jdbc-ds account-id))]
             (-> prices
                 to-json
                 response/ok
                 (response/header "Content-Type" "application/json"))
             (response/not-found (str "Prices not found for stocks in account: " (:account-id path-params))))))}}]
    ["/:for-date"
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)
               for-date (:for-date path-params)]
           (log/info "Get prices for stocks in account:" (:account-id path-params) "for date:" for-date)
           (if-let [prices (seq (prices/get-prices-for-account-at jdbc-ds account-id for-date))]
             (-> prices
                 to-json
                 response/ok
                 (response/header "Content-Type" "application/json"))
             (response/not-found (str "Prices not found for stocks in account: " (:account-id path-params))))))}}]]
   ["trades/:account-id"
    [""
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)
               trades (prices/account-trades jdbc-ds account-id nil nil)]
           (log/infof "Get account %s trades for all time %s" account-id trades)
           (-> trades
               to-json
               response/ok
               (response/header "Content-Type" "application/json"))))}}]
    ["/:start/:end"
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)
               trades (prices/account-trades jdbc-ds account-id (:start path-params) (:end path-params))]
           (log/infof "Get account %s trades from %s to %s: %s" account-id (:start path-params) (:end path-params) trades)
           (-> trades
               to-json
               response/ok
               (response/header "Content-Type" "application/json"))))}}]]
   ["positions/:account-id"
    [""
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)
               positions (prices/account-positions jdbc-ds account-id nil nil)]
           (log/infof "Get account %s positions for all time %s" account-id positions)
           (-> positions
               to-json
               response/ok
               (response/header "Content-Type" "application/json"))))}}]
    ["/:start/:end"
     {:allow-methods [:get]
      :get
      {:handler
       (fn [{:keys [path-params]}]
         (let [account-id (get-account-id path-params)
               positions (prices/account-positions jdbc-ds account-id (:start path-params) (:end path-params))]
           (log/infof "Get account %s positions from %s to %s: %s" account-id (:start path-params) (:end path-params) positions)
           (-> positions
               to-json
               response/ok
               (response/header "Content-Type" "application/json"))))}}]]
   ["points-in-time/:account-id"
    {:allow-methods [:get]
     :get
     {:handler
      (fn [{:keys [path-params]}]
        (let [account-id (get-account-id path-params)]
          (-> (prices/get-trade-points-in-time jdbc-ds account-id)
              to-json
              response/ok
              (response/header "Content-Type" "application/json"))))}}]
   ["trade-intervals/:account-id"
    {:allow-methods [:get]
     :get
     {:handler
      (fn [{:keys [path-params]}]
        (let [account-id (get-account-id path-params)]
          (-> (prices/get-trade-intervals jdbc-ds account-id)
              to-json
              response/ok
              (response/header "Content-Type" "application/json"))))}}]
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
  (r/match-by-path router "/trades/124")

  #_1)
