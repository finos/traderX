process.env.TRADE_FEED_PORT 

const ROUTES = [
    {
        url: '/refdata',
        proxy: {
            target: `http://localhost:${process.env.REFERENCE_DATA_SERVICE_PORT | 18085}`,
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
            target: `http://localhost:${process.env.DATABASE_WEB_PORT | 18084}`,
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
            target:  `http://localhost:${process.env.TRADING_SERVICE_PORT | 18092}`,
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
            target: `http://localhost:${process.env.PEOPLE_SERVICE_PORT | 18089}`,
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
            target: `http://localhost:${process.env.ACCOUNT_SERVICE_PORT | 18088}`,
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
            target: `http://localhost:${process.env.POSITION_SERVICE_PORT | 18090}`,
            changeOrigin: true,
            autoRewrite: true,

            pathRewrite: {
                [`^/positions`]: '',
            },
        }
    }
]

exports.routes = ROUTES;
