package finos.traderx.accountservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PersonDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link Person}
   *   <li>{@link Person#setDepartment(String)}
   *   <li>{@link Person#setEmail(String)}
   *   <li>{@link Person#setFullName(String)}
   *   <li>{@link Person#setLogonId(String)}
   *   <li>{@link Person#setPhotoUrl(String)}
   *   <li>{@link Person#toString()}
   *   <li>{@link Person#getDepartment()}
   *   <li>{@link Person#getEmail()}
   *   <li>{@link Person#getFullName()}
   *   <li>{@link Person#getLogonId()}
   *   <li>{@link Person#getPhotoUrl()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  void testGettersAndSetters() {
    // Arrange and Act
    Person actualPerson = new Person();
    actualPerson.setDepartment("Department");
    actualPerson.setEmail("jane.doe@example.org");
    actualPerson.setFullName("Dr Jane Doe");
    actualPerson.setLogonId("42");
    actualPerson.setPhotoUrl("https://example.org/example");
    String actualToStringResult = actualPerson.toString();
    String actualDepartment = actualPerson.getDepartment();
    String actualEmail = actualPerson.getEmail();
    String actualFullName = actualPerson.getFullName();
    String actualLogonId = actualPerson.getLogonId();

    // Assert that nothing has changed
    assertEquals("42", actualLogonId);
    assertEquals("Department", actualDepartment);
    assertEquals("Dr Jane Doe", actualFullName);
    assertEquals("Person: 42 | Dr Jane Doe | jane.doe@example.org | Department |", actualToStringResult);
    assertEquals("https://example.org/example", actualPerson.getPhotoUrl());
    assertEquals("jane.doe@example.org", actualEmail);
  }
}
