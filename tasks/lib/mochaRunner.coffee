Mocha = require 'mocha'
domain = require 'domain'
coffee = require 'coffee-script'
fs = require 'fs'

runner = (opts)->
  grep = opts.grep
  testPath = opts.test
  env = opts.env
  callback = opts.callback

  root = './test/functional/selenium2/compiled'
  test = root + testPath.replace('coffee', 'js')

  # compile test file
  testSrc = fs.readFileSync './test/functional/selenium2' + testPath, 
    encoding: 'utf8'
  testBuf = coffee.compile testSrc
  fs.writeFileSync test, testBuf

  # escape special characters for regex
  grep = grep
    .replace('(', '\\(')
    .replace(')', '\\)')
    .replace('[', '\\[')
    .replace(']', '\\]')
    .replace('.', '\\.')
    .replace('*', '\\*')
    .replace('?', '\\?')

  _grep = new RegExp(grep)

  mocha = new Mocha
    grep: _grep,
    reporter: 'spec'

  mocha.addFile root + '/configs/'+env+'.js'
  mocha.addFile root + '/configs/_base.js'
  mocha.addFile test

  try
    # This hack is a copy of the hack used in
    # https://github.com/gregrperkins/grunt-mocha-hack
    # to work around the issue that mocha lets uncaught exceptions
    # escape and grunt as of version 0.4.x likes to catch uncaught
    # exceptions and exit. It's nasty and requires intimate knowledge
    # of Mocha internals

    if mocha.files.length
      mocha.loadFiles()

    mochaSuite = mocha.suite
    mochaOptions = mocha.options
    mochaRunner = new Mocha.Runner(mochaSuite)
    mochaReporter = new mocha._reporter(mochaRunner)
    mochaRunner.ignoreLeaks = false != mochaOptions.ignoreLeaks
    mochaRunner.asyncOnly = mochaOptions.asyncOnly

    if mochaOptions.grep
      mochaRunner.grep(mochaOptions.grep, mochaOptions.invert)

    if mochaOptions.globals
      mochaRunner.globals(mochaOptions.globals)

    if mochaOptions.growl
      mocha._growl(mochaRunner, mochaReporter)

    Mocha.reporters.Base.useColors = true

    runDomain = domain.create()
    runDomain.on('error', mochaRunner.uncaught.bind(mochaRunner))
    runDomain.run ->
      mochaRunner.run (failureCount)->
        callback(null, failureCount)

    # I wish I could just do this...
    #
    # mocha.run(function(failureCount) {
    #   callback(null, failureCount)
    # })
  catch error
    # catch synchronous (uncaught) exceptions thrown as a result
    # of loading the test files so that they can be reported with
    # better details
    callback(error)

process.on 'message', (opts)->
  opts.callback = (error)->
    process.send error
  runner(opts)