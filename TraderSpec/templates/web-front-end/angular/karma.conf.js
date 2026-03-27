// Karma configuration file, see link for more information
// https://karma-runner.github.io/1.0/config/configuration-file.html

const path = require('path');

// See: https://github.com/karma-runner/karma-chrome-launcher#headless-chromium-with-puppeteer
process.env.CHROME_BIN = require('puppeteer').executablePath();

module.exports = function (config) {
    config.set({
        basePath: '',
        frameworks: ['jasmine', '@angular-devkit/build-angular'],
        plugins: [
            require('karma-jasmine'),
            require('karma-chrome-launcher'),
            require('karma-jasmine-html-reporter'),
            require('karma-coverage'),
            require('karma-junit-reporter'),
            require('@angular-devkit/build-angular/plugins/karma')
        ],
        client: {
            jasmine: {
                // you can add configuration options for Jasmine here
                // the possible options are listed at https://jasmine.github.io/api/edge/Configuration.html
                // for example, you can disable the random execution with `random: false`
                // or set a specific seed with `seed: 4321`
            },
            clearContext: false // leave Jasmine Spec Runner output visible in browser
        },
        coverageReporter: {
            dir: require('path').join(__dirname, '.test-results/coverage-results/karma-coverage'),
            subdir: '.',
            reporters: [
                { type: 'html', subdir: 'html' },
                { type: 'lcovonly' },
                { type: 'text-summary' }
            ],
            check: {
                global: { // thresholds for all files
                    statements: 10,
                    branches: 10,
                    functions: 10,
                    lines: 10
                },
                each: { // thresholds per file
                    statements: 0,
                    branches: 0,
                    functions: 0,
                    lines: 0
                }
            }
        },
        junitReporter: {
            outputDir: path.join(__dirname, '.test-results/junit'),
            xmlVersion: 1 // use '1' if reporting to be per SonarQube 6.2 XML format
        },
        reporters: ['progress', 'kjhtml', 'junit'],
        port: 9876,
        colors: true,
        logLevel: config.LOG_INFO,
        autoWatch: true,
        browsers: ['Chrome'],
        customLaunchers: {
            ChromeHeadlessNoSandbox: {
                base: 'ChromeHeadless',
                flags: ['--no-sandbox']
            }
        },
        singleRun: false,
        restartOnFileChange: true
    });
};
