package finos.traderx.accountservice.service;

import finos.traderx.accountservice.model.Person;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@Service
public class PeopleValidationService {

  private static final Logger LOGGER = LoggerFactory.getLogger(PeopleValidationService.class);

  private final RestTemplate restTemplate = new RestTemplate();
  private final String peopleServiceAddress;

  public PeopleValidationService(
      @Value("${people.service.url}") String peopleServiceAddress
  ) {
    this.peopleServiceAddress = peopleServiceAddress;
  }

  public boolean validatePerson(String username) {
    String url = peopleServiceAddress + "/People/GetPerson?LogonId=" + username;
    try {
      ResponseEntity<Person> response = restTemplate.getForEntity(url, Person.class);
      LOGGER.info("Validated person {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getStatusCode().value() == 404) {
        LOGGER.info("{} not found in people-service", username);
      } else {
        LOGGER.error("people-service lookup failed: {}", ex.getMessage());
      }
      return false;
    }
  }
}
