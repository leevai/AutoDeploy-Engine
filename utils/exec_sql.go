package utils

import (
	"AutoDeploy-Engine/config"
	"database/sql"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
)

func ExecMysqlSQL(sqlStatement string) (err error) {
	// ??????????????????????: username:password@tcp(host:port)/dbname
	dsn := fmt.Sprintf("%v:%v@tcp(%v:3306)/learn-jooq",
		config.GlobalConfigMap["mysqluser"],
		config.GlobalConfigMap["mysqlpassword"],
		config.GlobalConfigMap["mysqlhost"],
	)
	// ??????????????
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	// ??????????????
	if err := db.Ping(); err != nil {
		return err
	}

	// ????????????
	_, err = db.Exec(sqlStatement)
	if err != nil {
		return err
	}

	return
}
