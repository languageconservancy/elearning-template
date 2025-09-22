<?php

return [
    'debug' => true,

    'App.name' => 'eLearning Demo',
    'App.author' => 'The Language Conservancy',

    'Datasources.default.username' => 'root',
    'Datasources.default.password' => 'root',
    'Datasources.default.database' => 'elearning_demo_db',

    // Displayed in various places in the user interface.
    'LANGUAGE' => 'Demo Language',

    // Upload settings
    'SITEUPLOAD' => true,

    // Amazon Web Services settings
    'AWSUPLOAD' => false,
    'AWSBUCKETNAME' => '',
    'AWSREGION' => '',
    'AWS_LINK' => '',

    // Links to the frontend and backend
    'FROENTEND_LINK' => 'http://localhost:4200/',
    'ADMIN_LINK' => 'http://localhost/backend/',

    // Teacher Portal settings
    'CLASSROOMPATHID' => 2,
    'ALLUNITSLEVELID' => 0,
];
