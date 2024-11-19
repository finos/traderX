package finos.traderx.accountservice.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isA;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.repository.AccountRepository;
import finos.traderx.accountservice.repository.AccountUserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.repository.CrudRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {AccountUserService.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class AccountUserServiceDiffblueTest {
  @MockBean
  private AccountRepository accountRepository;

  @MockBean
  private AccountUserRepository accountUserRepository;

  @Autowired
  private AccountUserService accountUserService;

  /**
   * Test {@link AccountUserService#getAllAccountUsers()}.
   * <ul>
   *   <li>Given {@link AccountUser} (default constructor) AccountId is one.</li>
   *   <li>Then return {@link ArrayList#ArrayList()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAllAccountUsers()}
   */
  @Test
  @DisplayName("Test getAllAccountUsers(); given AccountUser (default constructor) AccountId is one; then return ArrayList()")
  void testGetAllAccountUsers_givenAccountUserAccountIdIsOne_thenReturnArrayList() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    ArrayList<AccountUser> accountUserList = new ArrayList<>();
    accountUserList.add(accountUser);
    when(accountUserRepository.findAll()).thenReturn(accountUserList);

    // Act
    List<AccountUser> actualAllAccountUsers = accountUserService.getAllAccountUsers();

    // Assert
    verify(accountUserRepository).findAll();
    assertEquals(accountUserList, actualAllAccountUsers);
  }

  /**
   * Test {@link AccountUserService#getAllAccountUsers()}.
   * <ul>
   *   <li>Given {@link AccountUser} (default constructor) AccountId is two.</li>
   *   <li>Then return size is two.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAllAccountUsers()}
   */
  @Test
  @DisplayName("Test getAllAccountUsers(); given AccountUser (default constructor) AccountId is two; then return size is two")
  void testGetAllAccountUsers_givenAccountUserAccountIdIsTwo_thenReturnSizeIsTwo() {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(2);
    accountUser2.setUsername("Username");

    ArrayList<AccountUser> accountUserList = new ArrayList<>();
    accountUserList.add(accountUser2);
    accountUserList.add(accountUser);
    when(accountUserRepository.findAll()).thenReturn(accountUserList);

    // Act
    List<AccountUser> actualAllAccountUsers = accountUserService.getAllAccountUsers();

    // Assert
    verify(accountUserRepository).findAll();
    assertEquals(2, actualAllAccountUsers.size());
    AccountUser getResult = actualAllAccountUsers.get(0);
    assertEquals("Username", getResult.getUsername());
    assertEquals(2, getResult.getAccountId().intValue());
    assertSame(accountUser, actualAllAccountUsers.get(1));
  }

  /**
   * Test {@link AccountUserService#getAllAccountUsers()}.
   * <ul>
   *   <li>Then return Empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAllAccountUsers()}
   */
  @Test
  @DisplayName("Test getAllAccountUsers(); then return Empty")
  void testGetAllAccountUsers_thenReturnEmpty() {
    // Arrange
    when(accountUserRepository.findAll()).thenReturn(new ArrayList<>());

    // Act
    List<AccountUser> actualAllAccountUsers = accountUserService.getAllAccountUsers();

    // Assert
    verify(accountUserRepository).findAll();
    assertTrue(actualAllAccountUsers.isEmpty());
  }

  /**
   * Test {@link AccountUserService#getAllAccountUsers()}.
   * <ul>
   *   <li>Then throw {@link ResourceNotFoundException}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAllAccountUsers()}
   */
  @Test
  @DisplayName("Test getAllAccountUsers(); then throw ResourceNotFoundException")
  void testGetAllAccountUsers_thenThrowResourceNotFoundException() {
    // Arrange
    when(accountUserRepository.findAll()).thenThrow(new ResourceNotFoundException("An error occurred"));

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountUserService.getAllAccountUsers());
    verify(accountUserRepository).findAll();
  }

  /**
   * Test {@link AccountUserService#getAccountUserById(int)}.
   * <p>
   * Method under test: {@link AccountUserService#getAccountUserById(int)}
   */
  @Test
  @DisplayName("Test getAccountUserById(int)")
  void testGetAccountUserById() throws ResourceNotFoundException {
    // Arrange
    when(accountUserRepository.findById(Mockito.<Integer>any()))
        .thenThrow(new ResourceNotFoundException("An error occurred"));

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountUserService.getAccountUserById(1));
    verify(accountUserRepository).findById(eq(1));
  }

  /**
   * Test {@link AccountUserService#getAccountUserById(int)}.
   * <ul>
   *   <li>Given {@link AccountUser} (default constructor) AccountId is one.</li>
   *   <li>Then return {@link AccountUser} (default constructor).</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAccountUserById(int)}
   */
  @Test
  @DisplayName("Test getAccountUserById(int); given AccountUser (default constructor) AccountId is one; then return AccountUser (default constructor)")
  void testGetAccountUserById_givenAccountUserAccountIdIsOne_thenReturnAccountUser() throws ResourceNotFoundException {
    // Arrange
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");
    Optional<AccountUser> ofResult = Optional.of(accountUser);
    when(accountUserRepository.findById(Mockito.<Integer>any())).thenReturn(ofResult);

    // Act
    AccountUser actualAccountUserById = accountUserService.getAccountUserById(1);

    // Assert
    verify(accountUserRepository).findById(eq(1));
    assertSame(accountUser, actualAccountUserById);
  }

  /**
   * Test {@link AccountUserService#getAccountUserById(int)}.
   * <ul>
   *   <li>Given {@link AccountUserRepository}
   * {@link CrudRepository#findById(Object)} return empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#getAccountUserById(int)}
   */
  @Test
  @DisplayName("Test getAccountUserById(int); given AccountUserRepository findById(Object) return empty")
  void testGetAccountUserById_givenAccountUserRepositoryFindByIdReturnEmpty() throws ResourceNotFoundException {
    // Arrange
    Optional<AccountUser> emptyResult = Optional.empty();
    when(accountUserRepository.findById(Mockito.<Integer>any())).thenReturn(emptyResult);

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountUserService.getAccountUserById(1));
    verify(accountUserRepository).findById(eq(1));
  }

  /**
   * Test {@link AccountUserService#upsertAccountUser(AccountUser)}.
   * <p>
   * Method under test: {@link AccountUserService#upsertAccountUser(AccountUser)}
   */
  @Test
  @DisplayName("Test upsertAccountUser(AccountUser)")
  void testUpsertAccountUser() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    Optional<Account> ofResult = Optional.of(account);
    when(accountRepository.findById(Mockito.<Integer>any())).thenReturn(ofResult);
    when(accountUserRepository.save(Mockito.<AccountUser>any()))
        .thenThrow(new ResourceNotFoundException("An error occurred"));

    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountUserService.upsertAccountUser(accountUser));
    verify(accountRepository).findById(eq(1));
    verify(accountUserRepository).save(isA(AccountUser.class));
  }

  /**
   * Test {@link AccountUserService#upsertAccountUser(AccountUser)}.
   * <ul>
   *   <li>Given {@link AccountRepository} {@link CrudRepository#findById(Object)}
   * return empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#upsertAccountUser(AccountUser)}
   */
  @Test
  @DisplayName("Test upsertAccountUser(AccountUser); given AccountRepository findById(Object) return empty")
  void testUpsertAccountUser_givenAccountRepositoryFindByIdReturnEmpty() {
    // Arrange
    Optional<Account> emptyResult = Optional.empty();
    when(accountRepository.findById(Mockito.<Integer>any())).thenReturn(emptyResult);

    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountUserService.upsertAccountUser(accountUser));
    verify(accountRepository).findById(eq(1));
  }

  /**
   * Test {@link AccountUserService#upsertAccountUser(AccountUser)}.
   * <ul>
   *   <li>Given {@link AccountUser} (default constructor) AccountId is one.</li>
   *   <li>Then return {@link AccountUser} (default constructor).</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountUserService#upsertAccountUser(AccountUser)}
   */
  @Test
  @DisplayName("Test upsertAccountUser(AccountUser); given AccountUser (default constructor) AccountId is one; then return AccountUser (default constructor)")
  void testUpsertAccountUser_givenAccountUserAccountIdIsOne_thenReturnAccountUser() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    Optional<Account> ofResult = Optional.of(account);
    when(accountRepository.findById(Mockito.<Integer>any())).thenReturn(ofResult);

    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(1);
    accountUser.setUsername("janedoe");
    when(accountUserRepository.save(Mockito.<AccountUser>any())).thenReturn(accountUser);

    AccountUser accountUser2 = new AccountUser();
    accountUser2.setAccountId(1);
    accountUser2.setUsername("janedoe");

    // Act
    AccountUser actualUpsertAccountUserResult = accountUserService.upsertAccountUser(accountUser2);

    // Assert
    verify(accountRepository).findById(eq(1));
    verify(accountUserRepository).save(isA(AccountUser.class));
    assertSame(accountUser, actualUpsertAccountUserResult);
  }
}
