const fs = require('fs')
const jwt = require('jsonwebtoken');
const path = require('path')

const now = new Date();
const origin = "https://jbmorley.co.uk";
const authKey = process.env.JWT_PRIVATE_KEY;

const header = {
    kid: "9JWTV3AY48",
    typ: "JWT",
    alg: "ES256"
};

var payload = {
    iss: "S4WXAUZQEV",
    iat: now / 1000,
    exp: (now / 1000) + 15778800,
    origin: origin
};

const authorizationToken = jwt.sign(payload, authKey, { algorithm: 'ES256', header: header })
console.log(authorizationToken)
