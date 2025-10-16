package finos.traderx.accountservice.service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.repository.AccountRepository;
import finos.traderx.accountservice.repository.AccountUserRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class AccountUserService {

	@Autowired
	AccountUserRepository accountUserRepository;

	@Autowired
	AccountRepository accountRepository;

	public List<AccountUser> getAllAccountUsers() {
		return StreamSupport.stream(this.accountUserRepository.findAll().spliterator(), false)
			.collect(Collectors.toList());
	}

	public AccountUser getAccountUserById(int id) throws ResourceNotFoundException {
		Optional<AccountUser> accountUser = this.accountUserRepository.findById(Integer.valueOf(id));
		if (accountUser.isEmpty()) {
			throw new ResourceNotFoundException("AccountUser with id " + id + "not found");
		}
		return accountUser.get();
	}

	public AccountUser upsertAccountUser(AccountUser accountUser) {
		Optional<Account> account = this.accountRepository.findById(accountUser.getAccountId());
		if (account.isEmpty()) {
			throw new ResourceNotFoundException("Account with id " + accountUser.getAccountId() + "not found");
		}
		return this.accountUserRepository.save(accountUser);
	}

}
