<?php

return [
    'debug' => true,

    'App.name' => 'eLearning Staging',
    'App.author' => 'The Language Conservancy',

    'Datasources.default.database' => 'elearning_staging_db',

    // Displayed in various places in the user interface.
    'LANGUAGE' => 'Staging Language',

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
    'CLASSROOMPATHID' => 0,
    'ALLUNITSLEVELID' => 0,
];
