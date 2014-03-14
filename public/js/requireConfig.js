var require = {
    baseUrl: "js",
    paths: {
        b2: 'b2',
        backbone: ['vendor/backbone/backbone'],
        box2d: ['vendor/Box2dWeb-2.1.a.3'],
        canvasquery: ['vendor/canvasquery'],
        "dat.gui": 'vendor/dat.gui',
        'canvasquery.framework': ['vendor/canvasquery.framework'],
        jquery: ['vendor/jquery-1.9.1.min', '//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min'],
        noise: ['vendor/noise'],
        pathfinding: ['vendor/PathFinding.js/lib/pathfinding-browser'],
        seedrandom: ['vendor/seedrandom'],
        'socket.io': ['/socket.io/socket.io'],
        stats: ['vendor/stats'],
        underscore: ['vendor/underscore/underscore'],

    },
    shim: {
        box2d: {
            exports: 'Box2D'
        },
        canvasquery: {
            exports: ['cq', 'CanvasQuery']
        },
        'canvasquery.framework': {
            deps: ['canvasquery'],
            exports: ['cq', 'CanvasQuery']
        },
        "dat.gui": {
            exports: 'dat'
        },
        noise: {
            exports: 'ClassicalNoise'
        },
        settings: {
            exports: 'settings'
        },
        stats: {
            exports: 'Stats'
        },
        underscore: {
            exports: '_'
        },
    }
};

