# grunt-parallel-mocha 
fs = require 'fs'
child_process = require 'child_process'
coffee = require 'coffee-script'
wrench = require 'wrench'

module.exports = (grunt)->
  grunt.registerMultiTask 'parallelMocha', 'saucelabs parallel testing', ()->
    self = @
    # process options
    flags = grunt.option.flags()
    flags.forEach (flag)->
      value = flag.split('=')[1]
      option = flag.split('=')[0].substr(2)
      self.data.options[option] = value

    env = @data.options.env
    grep = @data.options.grep

    done = this.async()
    root = './test/functional/selenium2'
    npmRoot = './node_modules/grunt-parallel-mocha/'

    compileAll = (src, dest)->
      # get file name
      file = '/' + src.split('/').pop()

      # check if src is a directory
      stats = new fs.lstatSync(src)
      if stats.isDirectory()
        # create directory in dest
        fs.mkdirSync dest + file
        newDir = dest + file
        # loop through contents
        fs.readdirSync(src).forEach (file)->
          # recurse (file, newDir)
          compileAll(src + '/' + file, newDir)
      # check if coffee
      else if file.match /coffee/
        # compile in dest
        fileSrc = fs.readFileSync src, 
          encoding: 'utf8'
        fileCompiled = coffee.compile fileSrc
        fs.writeFileSync dest + file.replace('coffee', 'js'), fileCompiled

    getSpecNamesFromFile = (path)->
      file = fs.readFileSync path, 
        encoding: 'utf8'

      if file.match(/describe.skip/)
        return []

      # get all spec titles in file and return them as an array
      file.match(/it(.*)->/g).map((spec)->
        title = spec.match(/\'(.*)\'/)[1]

        if grep 
          grepRE = new RegExp(grep)

        if !spec.match(/it\.skip/)
          if !grepRE or grepRE.test(title)
            return title
      ).filter (spec)->
        return !!spec
    
    getTests = (path)->
      path = path || ''
      
      tests = fs.readdirSync(root + path)
      
      tests.forEach (file)->
        _path = path + '/' + file
        
        stats = new fs.lstatSync(root + _path)
        
        if /\.coffee/.test file
          specs = getSpecNamesFromFile(root + _path)

          # loop through all specs in file
          specs.forEach (spec)->
            # spawn child process for spec
            child = child_process.fork npmRoot + './tasks/lib/mochaRunner.js',
              stdio: 'inherit'  

            child.on 'message', (error)->
              if error
                grunt.log.error error.code
              child.kill()

            child.send
              test: _path, 
              grep: spec,
              env: env

        else if stats.isDirectory()
          if !fs.existsSync root + '/compiled' + _path
            fs.mkdirSync root + '/compiled' + _path
          getTests(_path)

    compileAll(npmRoot + './tasks/lib/mochaRunner.coffee', npmRoot + './tasks/lib/')

    # create compile destination folder, and delete it if it already exists
    if fs.existsSync(root + '/compiled')
      wrench.rmdirSyncRecursive root + '/compiled'
    wrench.mkdirSyncRecursive root + '/compiled'

    # list dependancies
    dependancies = ['/components', '/configs', '/tests']

    # compile all dependancies
    dependancies.forEach (dep)->
      source = root + dep
      dest = root + '/compiled'

      # pass off to recursive directory compiler
      compileAll(source, dest)

    getTests('/tests/desktop')
