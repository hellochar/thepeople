
/**
 * Module dependencies.
 */

var express = require('express');
var routes = require('./routes');
var user = require('./routes/user');
var http = require('http');
var path = require('path');
var livereload = require('connect-livereload');

var app = express();

// development only
if ('development' == app.get('env')) {
  app.use(express.errorHandler());
  app.use(livereload());
}

// all environments
app.set('port', process.env.PORT || 3000);
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');
app.use(express.favicon());
app.use(express.logger('dev'));
app.use(express.json());
app.use(express.urlencoded());
app.use(express.methodOverride());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));
app.use('/js/vendor', express.static(path.join(__dirname, 'bower_components')));
app.use(express.static(path.join(__dirname, 'compiled')));

app.get('/', routes.index);

http.createServer(app).listen(app.get('port'), function(){
  console.log('Express server listening on port ' + app.get('port'));
});

require('fs').writeFileSync('.rebooted', 'rebooted')
