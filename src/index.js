const Express= require("express");
const sequelize= require("/config/database");
const app= express();
sequelize.authenticate().then(()=>{
    console.log ("database connected successfully");
    app.listen(5000,()=>{
        console.log("backend is running ");});
    })
 app.get("/status",(req,res) =>{
    console.log("backend is in good health");
    return res.json({status: "up and running"});
 });

