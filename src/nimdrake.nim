import /[database, query, query_result, value]

let duck = connect()

echo duck.execute("SELECT * FROM range(100) AS example;")

export database,
       query,
       query_result
