(ns reference-service.web.middleware)

(defn add-cors-headers
  [response]
  (-> response
      (assoc-in [:headers "Access-Control-Allow-Origin"] "*")
      (assoc-in [:headers "Access-Control-Allow-Methods"] "GET, POST, PUT, DELETE, OPTIONS")
      (assoc-in [:headers "Access-Control-Allow-Headers"] "Content-Type, Authorization, Accept")))

(def cors-middleware
  {:name ::cors
   :compile (fn cors-compile [{:keys [_allowed-methods]} _]
              (fn cors-middleware [handler]
                (fn
                  ([request]
                   (add-cors-headers (handler request))))))})

(defn wrap-exceptions
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch Exception e
        (add-cors-headers
         {:status 400
          :body {:error (.getMessage e)}})))))
