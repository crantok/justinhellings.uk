<?php

// Recaptcha check taken from https://gist.github.com/jonathanstark/dfb30bdfb522318fc819
//
$post_data = http_build_query(
    array(
        'secret' => '6LcBkUMUAAAAAAhxuJPmXuMNOFjn4AcgyCH6gj4_',
        'response' => $_POST['g-recaptcha-response'],
        'remoteip' => $_SERVER['REMOTE_ADDR']
    )
);
$opts = array('http' =>
    array(
        'method'  => 'POST',
        'header'  => 'Content-type: application/x-www-form-urlencoded',
        'content' => $post_data
    )
);
$context  = stream_context_create($opts);
$response = file_get_contents('https://www.google.com/recaptcha/api/siteverify', false, $context);
$result = json_decode($response);


$status = '';
$query_params = '?' . http_build_query(
    array(
        'your-message' => $_POST['your-message'],
        'your-email' => $_POST['your-email'],
        'your-name' => $_POST['your-name'],
    ));


if (empty($result->success)) {
    $status = "mail-captcha";

} else {
    $to = 'info@justinhellings.uk';
    $subject = '[justinhellings.uk] Contact-form message from '. $_POST['your-name'];
    $message = $_POST['your-message'];
    $from = $to;
    $reply_to = $_POST['your-email'];
    $headers = 'From: '.$from."\r\nReply-To: ".$reply_to."\r\n";
    $sender = '-f '.$from;
    $result = mail($to, $subject, $message, $headers, $sender);
    
    if (empty($result)){
    $status =  'mail-failed';
    } else {
    $status =  'mail-sent';
        $query_params = '';
    }
}

header('Location: ' . $_POST['page-location'] . $query_params .'#'. $status, true, 303);
exit();
