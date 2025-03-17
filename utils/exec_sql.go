package utils

import (
	"AutoDeploy-Engine/config"
	"database/sql"
	"fmt"
	_ "gitee.com/opengauss/openGauss-connector-go-pq"
	_ "github.com/go-sql-driver/mysql"
)

func ExecMysqlSQL(sqlStatement string) (err error) {
	return ExecMysqlSQLWithDB("", sqlStatement)
}

func ExecMysqlSQLWithDB(dataBase, sqlStatement string) (err error) {
	dsn := fmt.Sprintf("%v:%v@tcp(%v:3306)/%s",
		config.GlobalConfigMap["mysqluser"],
		config.GlobalConfigMap["mysqlpassword"],
		config.GlobalConfigMap["mysqlhost"],
		dataBase,
	)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return err
	}
	_, err = db.Exec(sqlStatement)
	if err != nil {
		return err
	}
	return
}

func ExecMogDBSQL(sqlStatement string) (err error) {
	dsn := fmt.Sprintf("host=%v port=%v user=%v password=%v dbname=zcloud sslmode=disable",
		config.GlobalConfigMap["mogdbhost"],
		config.GlobalConfigMap["mogdbport"],
		config.GlobalConfigMap["mogdbuser"],
		config.GlobalConfigMap["mogdbpassword"],
	)
	db, err := sql.Open("mogdb", dsn)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return err
	}
	_, err = db.Exec(sqlStatement)
	if err != nil {
		return err
	}
	return
}
