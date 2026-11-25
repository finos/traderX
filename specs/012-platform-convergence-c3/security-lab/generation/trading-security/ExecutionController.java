package __PACKAGE__.security;

import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.BAD_REQUEST;

@RestController
public final class ExecutionController {
  private final JdbcTemplate jdbc;
  public ExecutionController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

  @PostMapping("/internal/executions/{id}")
  public Map<String,String> execute(@PathVariable("id") UUID id, @RequestBody(required=false) String body) {
    if (body != null && !body.isBlank()) throw new ResponseStatusException(BAD_REQUEST,"Execution accepts an identifier only");
    String receipt;
    try { receipt = jdbc.queryForObject("SELECT lab_execution.settle(?)",String.class,id); }
    catch (org.springframework.dao.DataAccessException failure) {
      Throwable cause = failure.getMostSpecificCause();
      if (cause instanceof java.sql.SQLException sql && "22023".equals(sql.getSQLState()))
        throw new ResponseStatusException(org.springframework.http.HttpStatus.CONFLICT,"Execution unavailable");
      throw new ResponseStatusException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE,"Execution unavailable");
    }
    if (receipt == null || !receipt.equals(id.toString())) throw new IllegalStateException("Execution receipt mismatch");
    return Map.of("executionId",id.toString(),"tradeId",receipt);
  }
}
