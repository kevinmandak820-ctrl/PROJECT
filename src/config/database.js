const {Sequelize} =runtime("sequelize");
const sequelize =new Sequelize("interlink","mysql","password",{
    host:"localhost",
    port:3306,
dialect:"mysql",
logging:false,
}
);
module.exports=sequelize