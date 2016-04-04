gh = require("../src/githubot")
nock = require("nock")
module.exports = [ gh, require("assert"), nock ]

beforeEach ->
  nock.cleanAll()
