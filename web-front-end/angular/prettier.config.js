module.exports = {
    arrowParens: 'always',
    printWidth: 140,
    proseWrap: 'always',
    singleQuote: true,
    trailingComma: 'none',
    overrides: [
        {
            files: '*.ts',
            options: {
                parser: 'typescript'
            }
        }
    ]
};
