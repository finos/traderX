package finos.traderx.accountservice.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import com.diffblue.cover.annotations.MethodsUnderTest;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.model.AccountUserID;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.repository.CrudRepository;
import org.springframework.test.context.ContextConfiguration;

@ContextConfiguration(classes = {AccountUserRepository.class})
@DataJpaTest
@EnableAutoConfiguration
@EntityScan(basePackages = {"finos.traderx.accountservice.model"})
class AccountUserRepositoryDiffblueTest {
  @Autowired
  private AccountUserRepository accountUserRepository;

  /**
   * Test {@link AccountUserRepository#findByAccountId(Integer)}.
   * <p>
   * Method under test: {@link AccountUserRepository#findByAccountId(Integer)}
   */
  @Test
  @DisplayName("Test findByAccountId(Integer)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Optional AccountUserRepository.findByAccountId(Integer)"})
  void testFindByAccountId() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    // Act
    Optional<AccountUser> actualFindByAccountIdResult = accountUserRepository.findByAccountId(1);

    // Assert
    AccountUser getResult = actualFindByAccountIdResult.get();
    assertEquals("janedoe", getResult.getUsername());
    assertEquals(1, getResult.getAccountId().intValue());
    assertTrue(actualFindByAccountIdResult.isPresent());
  }

  /**
   * Test {@link CrudRepository#count()}.
   * <p>
   * Method under test: {@link AccountUserRepository#count()}
   */
  @Test
  @DisplayName("Test count()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"long AccountUserRepository.count()"})
  void testCount() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    // Act and Assert
    assertEquals(2L, accountUserRepository.count());
  }

  /**
   * Test {@link CrudRepository#delete(Object)}.
   * <p>
   * Method under test: {@link AccountUserRepository#delete(Object)}
   */
  @Test
  @DisplayName("Test delete(Object)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserRepository.delete(Object)"})
  void testDelete() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");

    AccountUser accountUser3 = new AccountUser();
    accountUser3.setAccountId(1);
    accountUser3.setUsername("janedoe");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);
    accountUserRepository.save(accountUser3);

    // Act
    accountUserRepository.delete(accountUser3);

    // Assert
    Iterable<AccountUser> findAllResult = accountUserRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(1, ((List<AccountUser>) findAllResult).size());
    AccountUser getResult = ((List<AccountUser>) findAllResult).get(0);
    assertEquals("Username", getResult.getUsername());
    assertEquals(2, getResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#deleteAll()}.
   * <p>
   * Method under test: {@link AccountUserRepository#deleteAll()}
   */
  @Test
  @DisplayName("Test deleteAll()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserRepository.deleteAll()"})
  void testDeleteAll() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    // Act
    accountUserRepository.deleteAll();

    // Assert
    Iterable<AccountUser> findAllResult = accountUserRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertTrue(((List<AccountUser>) findAllResult).isEmpty());
  }

  /**
   * Test {@link CrudRepository#deleteAllById(Iterable)}.
   * <p>
   * Method under test: {@link AccountUserRepository#deleteAllById(Iterable)}
   */
  @Test
  @DisplayName("Test deleteAllById(Iterable)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserRepository.deleteAllById(Iterable)"})
  void testDeleteAllById() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    AccountUserID accountUserID2 = new AccountUserID();
    accountUserID2.setAccountId(1);
    accountUserID2.setUsername("janedoe");

    AccountUserID accountUserID3 = new AccountUserID();
    accountUserID3.setAccountId(1);
    accountUserID3.setUsername("janedoe");
    List<AccountUserID> ids = Arrays.asList(accountUserID, accountUserID2, accountUserID3);

    // Act
    accountUserRepository.deleteAllById(ids);

    // Assert
    Iterable<AccountUser> findAllResult = accountUserRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(1, ((List<AccountUser>) findAllResult).size());
    AccountUser getResult = ((List<AccountUser>) findAllResult).get(0);
    assertEquals("Username", getResult.getUsername());
    assertEquals(2, getResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#deleteAll(Iterable)} with {@code Iterable}.
   * <p>
   * Method under test: {@link AccountUserRepository#deleteAll(Iterable)}
   */
  @Test
  @DisplayName("Test deleteAll(Iterable) with 'Iterable'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserRepository.deleteAll(Iterable)"})
  void testDeleteAllWithIterable() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");

    AccountUser accountUser3 = new AccountUser();
    accountUser3.setAccountId(1);
    accountUser3.setUsername("janedoe");

    AccountUser accountUser4 = new AccountUser();
    accountUser4.setAccountId(1);
    accountUser4.setUsername("janedoe");

    AccountUser accountUser5 = new AccountUser();
    accountUser5.setAccountId(1);
    accountUser5.setUsername("janedoe");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);
    accountUserRepository.save(accountUser3);
    accountUserRepository.save(accountUser4);
    accountUserRepository.save(accountUser5);
    List<AccountUser> entities = Arrays.asList(accountUser3, accountUser4, accountUser5);

    // Act
    accountUserRepository.deleteAll(entities);

    // Assert
    Iterable<AccountUser> findAllResult = accountUserRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(1, ((List<AccountUser>) findAllResult).size());
    AccountUser getResult = ((List<AccountUser>) findAllResult).get(0);
    assertEquals("Username", getResult.getUsername());
    assertEquals(2, getResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#deleteById(Object)}.
   * <p>
   * Method under test: {@link AccountUserRepository#deleteById(Object)}
   */
  @Test
  @DisplayName("Test deleteById(Object)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserRepository.deleteById(Object)"})
  void testDeleteById() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    // Act
    accountUserRepository.deleteById(accountUserID);

    // Assert
    Iterable<AccountUser> findAllResult = accountUserRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(1, ((List<AccountUser>) findAllResult).size());
    AccountUser getResult = ((List<AccountUser>) findAllResult).get(0);
    assertEquals("Username", getResult.getUsername());
    assertEquals(2, getResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#existsById(Object)}.
   * <ul>
   *   <li>Given {@link AccountUser} (default constructor) AccountId is one.</li>
   *   <li>Then return {@code true}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserRepository#existsById(Object)}
   */
  @Test
  @DisplayName("Test existsById(Object); given AccountUser (default constructor) AccountId is one; then return 'true'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"boolean AccountUserRepository.existsById(Object)"})
  void testExistsById_givenAccountUserAccountIdIsOne_thenReturnTrue() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    // Act and Assert
    assertTrue(accountUserRepository.existsById(accountUserID));
  }

  /**
   * Test {@link CrudRepository#existsById(Object)}.
   * <ul>
   *   <li>Then return {@code false}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserRepository#existsById(Object)}
   */
  @Test
  @DisplayName("Test existsById(Object); then return 'false'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"boolean AccountUserRepository.existsById(Object)"})
  void testExistsById_thenReturnFalse() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(2);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    // Act and Assert
    assertFalse(accountUserRepository.existsById(accountUserID));
  }

  /**
   * Test {@link CrudRepository#findAll()}.
   * <p>
   * Method under test: {@link AccountUserRepository#findAll()}
   */
  @Test
  @DisplayName("Test findAll()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Iterable AccountUserRepository.findAll()"})
  void testFindAll() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    // Act
    Iterable<AccountUser> actualFindAllResult = accountUserRepository.findAll();

    // Assert
    assertTrue(actualFindAllResult instanceof List);
    assertEquals(2, ((List<AccountUser>) actualFindAllResult).size());
    AccountUser getResult = ((List<AccountUser>) actualFindAllResult).get(1);
    assertEquals("Username", getResult.getUsername());
    AccountUser getResult2 = ((List<AccountUser>) actualFindAllResult).get(0);
    assertEquals("janedoe", getResult2.getUsername());
    assertEquals(1, getResult2.getAccountId().intValue());
    assertEquals(2, getResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#findAllById(Iterable)}.
   * <p>
   * Method under test: {@link AccountUserRepository#findAllById(Iterable)}
   */
  @Test
  @DisplayName("Test findAllById(Iterable)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Iterable AccountUserRepository.findAllById(Iterable)"})
  void testFindAllById() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    AccountUserID accountUserID2 = new AccountUserID();
    accountUserID2.setAccountId(1);
    accountUserID2.setUsername("janedoe");

    AccountUserID accountUserID3 = new AccountUserID();
    accountUserID3.setAccountId(1);
    accountUserID3.setUsername("janedoe");
    List<AccountUserID> ids = Arrays.asList(accountUserID, accountUserID2, accountUserID3);

    // Act
    Iterable<AccountUser> actualFindAllByIdResult = accountUserRepository.findAllById(ids);

    // Assert
    assertTrue(actualFindAllByIdResult instanceof List);
    assertEquals(3, ((List<AccountUser>) actualFindAllByIdResult).size());
    AccountUser getResult = ((List<AccountUser>) actualFindAllByIdResult).get(0);
    assertEquals("janedoe", getResult.getUsername());
    assertEquals(1, getResult.getAccountId().intValue());
    assertSame(getResult, ((List<AccountUser>) actualFindAllByIdResult).get(1));
    assertSame(getResult, ((List<AccountUser>) actualFindAllByIdResult).get(2));
  }

  /**
   * Test {@link CrudRepository#findById(Object)}.
   * <p>
   * Method under test: {@link AccountUserRepository#findById(Object)}
   */
  @Test
  @DisplayName("Test findById(Object)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Optional AccountUserRepository.findById(Object)"})
  void testFindById() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");
    accountUserRepository.save(accountUser);
    accountUserRepository.save(accountUser2);

    AccountUserID accountUserID = new AccountUserID();
    accountUserID.setAccountId(1);
    accountUserID.setUsername("janedoe");

    // Act
    Optional<AccountUser> actualFindByIdResult = accountUserRepository.findById(accountUserID);

    // Assert
    AccountUser getResult = actualFindByIdResult.get();
    assertEquals("janedoe", getResult.getUsername());
    assertEquals(1, getResult.getAccountId().intValue());
    assertTrue(actualFindByIdResult.isPresent());
  }

  /**
   * Test {@link CrudRepository#save(Object)}.
   * <p>
   * Method under test: {@link AccountUserRepository#save(Object)}
   */
  @Test
  @DisplayName("Test save(Object)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Object AccountUserRepository.save(Object)"})
  void testSave() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    // Act
    AccountUser actualSaveResult = accountUserRepository.save(accountUser);

    // Assert
    assertEquals("janedoe", actualSaveResult.getUsername());
    assertEquals(1, actualSaveResult.getAccountId().intValue());
  }

  /**
   * Test {@link CrudRepository#saveAll(Iterable)}.
   * <p>
   * Method under test: {@link AccountUserRepository#saveAll(Iterable)}
   */
  @Test
  @DisplayName("Test saveAll(Iterable)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Iterable AccountUserRepository.saveAll(Iterable)"})
  void testSaveAll() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(1);
    accountUser2.setUsername("janedoe");

    AccountUser accountUser3 = new AccountUser();
    accountUser3.setAccountId(1);
    accountUser3.setUsername("janedoe");
    List<AccountUser> entities = Arrays.asList(accountUser, accountUser2, accountUser3);

    // Act
    Iterable<AccountUser> actualSaveAllResult = accountUserRepository.saveAll(entities);

    // Assert
    assertTrue(actualSaveAllResult instanceof List);
    assertEquals(3, ((List<AccountUser>) actualSaveAllResult).size());
    AccountUser getResult = ((List<AccountUser>) actualSaveAllResult).get(0);
    assertEquals("janedoe", getResult.getUsername());
    assertEquals(1, getResult.getAccountId().intValue());
    assertSame(getResult, ((List<AccountUser>) actualSaveAllResult).get(1));
    assertSame(getResult, ((List<AccountUser>) actualSaveAllResult).get(2));
  }
}
