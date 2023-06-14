import { useEffect, useState } from "react";
import { AccountData } from "../AccountsDropdown";
import { Environment } from '../env';

export const GetAccounts = () => {
	const [accounts, setAccounts] = useState<AccountData[]>([]);
  useEffect(() => {
    const loadAccounts = async () => {
      const response = await fetch(`${Environment.account_service_url}/account/`);
      // const response = await fetch(`/account/`)
      if (response.ok) {
        const accounts = await response.json();
        setAccounts(accounts);
      }
      else {
        console.log('error');
      }
      // setAccounts(accountData);
    }
    loadAccounts();
  }, [setAccounts]);
	return accounts
}
