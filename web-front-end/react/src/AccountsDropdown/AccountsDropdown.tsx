import { MouseEvent, ReactNode, useEffect, useState } from 'react';
import InputLabel from '@mui/material/InputLabel';
import MenuItem from '@mui/material/MenuItem';
import FormControl from '@mui/material/FormControl';
import Select from '@mui/material/Select';
import { SelectChangeEvent } from '@mui/material';
import React from 'react';
import { GetAccounts } from '../hooks';
import { AccountData, AccountsDropdownProps } from './types';

export const AccountsDropdown = ({handleChange, currentAccount}:AccountsDropdownProps) => {
  const accounts = GetAccounts()
  const accountUsers = accounts.map((account:AccountData) => {
    return (
      <MenuItem
        value={account.id}
        key={account.id}
      >
        {account.displayName}
      </MenuItem>
    )
  })

  return (
      <FormControl sx={{ m: 1, minWidth: 120 }} size="small">
        <InputLabel>Accounts</InputLabel>
        <Select
          value={currentAccount}
          label="Accounts"
          onChange={handleChange}
        >
          <MenuItem value="">
            <em>None</em>
          </MenuItem>
          {accountUsers}
        </Select>
      </FormControl>
  );
}