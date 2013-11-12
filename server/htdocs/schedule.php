<?
require "lib.php";

$username = $_GET["username"];

$db = getDb();
$rs = pg_query_params("SELECT pd.day, pd.availability, pd.note
                         FROM person p
                         JOIN person_day pd ON p.id = pd.person
                        WHERE p.username = $1
                        ORDER BY pd.day",
                        array($username));
$data = pg_fetch_all($rs);

header("Content-type: text/plain");
echo(json_encode($data, JSON_PRETTY_PRINT));
?>