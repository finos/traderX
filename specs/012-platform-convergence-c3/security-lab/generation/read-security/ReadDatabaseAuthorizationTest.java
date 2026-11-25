package __PACKAGE__.security;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={
 "spring.datasource.url=jdbc:h2:mem:readsecurity;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
 "spring.datasource.driver-class-name=org.h2.Driver", "spring.datasource.username=sa", "spring.datasource.password=sa"
})
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
class ReadDatabaseAuthorizationTest extends SecurityTestSupport {
  @Autowired JdbcTemplate jdbc;
  @Test void databaseBackedReadsPreserveIsolationAndSourceData() throws Exception {
    jdbc.execute("CREATE TABLE Positions(AccountID int,Security varchar(16),Quantity int,AverageCostBasis decimal(18,3),Updated timestamp)");
    jdbc.execute("CREATE TABLE Trades(ID varchar(50),AccountID int,Security varchar(16),Side varchar(10),State varchar(20),Quantity int,Price decimal(18,3),Updated timestamp,Created timestamp)");
    jdbc.update("INSERT INTO Positions VALUES(22214,'IBM',10,99,CURRENT_TIMESTAMP),(44044,'MSFT',20,100,CURRENT_TIMESTAMP)");
    jdbc.update("INSERT INTO Trades VALUES('own',22214,'IBM','Buy','Settled',10,99,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),('foreign',44044,'MSFT','Buy','Settled',20,100,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
    var positions=jdbc.queryForList("SELECT * FROM Positions ORDER BY AccountID");
    var trades=jdbc.queryForList("SELECT * FROM Trades ORDER BY ID");
    for(String path:java.util.List.of("/positions/","/trades/","/positions/22214","/trades/22214"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader"))).andExpect(status().isOk())
        .andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].accountId").value(22214));
    for(String path:java.util.List.of("/positions/44044","/trades/44044"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    mvc.perform(get("/trades/44044").header("Authorization","Bearer "+token("other"))).andExpect(status().isOk())
      .andExpect(jsonPath("$[0].id").value("foreign"));
    assertEquals(positions,jdbc.queryForList("SELECT * FROM Positions ORDER BY AccountID"));
    assertEquals(trades,jdbc.queryForList("SELECT * FROM Trades ORDER BY ID"));
  }
}
