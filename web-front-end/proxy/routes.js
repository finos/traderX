const ROUTES = [
    {
        url: '/refdata',
        proxy: {
            target: "http://localhost:18085",
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/refdata`]: '',
            },
        }
    },
    {
        url: '/database',
        proxy: {
            target: "http://localhost:18084",
            changeOrigin: true,
            autoRewrite: true,
            pathRewrite: {
               [`^/database`]: '',
            },
        }
    },
    {
        url: '/trade',

        proxy: {
            target: "http://localhost:18092",
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/trade`]: '',
            },
        }
    }
    ,
    {
        url: '/people',

        proxy: {
            target: "http://localhost:18089",
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/people`]: '',
            },
        }
    }
    ,
    {
        url: '/accounts',

        proxy: {
            target: "http://localhost:18088",
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/accounts`]: '',
            },
        }
    } ,
    {
        url: '/positions',

        proxy: {
            target: "http://localhost:18090",
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/positions`]: '',
            },
        }
    }
]

exports.routes = ROUTES;
