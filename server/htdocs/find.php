<?
require "lib.php";

$skill = $_GET["skill"];
$day = $_GET["day"];

$db = getDb();
$rs = pg_query_params("SELECT p.username,
                              p.firstname,
                              p.lastname,
                              p.email,
                              p.message
                         FROM person p
                         JOIN person_day pd ON p.id = pd.person
                         JOIN person_skill ps ON p.id = ps.person
                         JOIN skill s ON ps.skill = s.id
                        WHERE pd.availability = 'AVAILABLE'
                          AND pd.day = $1::DATE
                          and s.name = $2
                        ORDER BY p.firstname, p.lastname",
                        array($day, $skill));
$data = pg_fetch_all($rs);                             

header("Content-type: text/plain");
echo(json_encode($data, JSON_PRETTY_PRINT));
?>