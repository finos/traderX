//This is based on a code example at https://github.com/JanssenBrm/api-gateway

const express = require('express')

const {routes} = require("./routes");
const morgan = require("morgan");

const app = express()
app.use(morgan('combined'));
const port = process.env.WEB_SERVICE_PORT || 18093;

const { createProxyMiddleware } = require('http-proxy-middleware');
routes.forEach(r => {
    app.use(r.url, createProxyMiddleware(r.proxy));
})

app.listen(port, () => {
    console.log(`Example app listening at http://localhost:${port}`)
})
