import { Box, Button, Modal, } from "@mui/material"
import { FormEvent, SetStateAction, useCallback, useState } from "react";
import { RJSFSchema, } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import Form, { IChangeEvent } from '@rjsf/core';
import { style } from "../style";
import { ActionButtonsProps, PeopleData } from "./types";
import { MatchingPeople } from "../AccountsDropdown";

export const CreateAccountUser = (
	{accountId}:ActionButtonsProps
	) => {
	const [matchingPeople, setMatchingPeople] = useState<MatchingPeople[]>([]);
	const schema: RJSFSchema = {
		title: 'Create/Update Account Users',
		type: 'object',
		required: ['username, fullName'],
		properties: {
			fullName: { type: 'string', title: 'Full Name' },
			username: { type: 'string', title: 'Username' },
		},
	};
	const uiSchema = {
		"type": "VerticalLayout",
		"elements": [
			{
				"type": "Control",
				"scope": "#/properties/''",
				"options": {
					"ui:widget": "button",
					"autocomplete": true
				}
			}
		],
	}
	const [open, setOpen] = useState<boolean>(false);
  const handleClose = () => setOpen(false);
	const handleOpen = () => setOpen(true);
	const log = (type:string) => console.log.bind(console, type);

	const onSubmit = async (data: IChangeEvent<any>, _event: FormEvent<any>) => {
		const accountDetails = data.formData;
		try {
				await fetch('http://127.0.0.1:18088/accountuser/', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						id: accountId,
						displayName: accountDetails.displayName
					}),
				});
				setOpen(false);
				console.log('success');
		} catch (error) {
			return error
		}
	}

	const onChange = useCallback(async (data: IChangeEvent<any>) => {
		let json:PeopleData[];
		console.log(data.formData)
			try {
					const response = await fetch(`http://127.0.0.1:18095/People/GetMatchingPeople?SearchText=${data.formData.fullName}`);
					json = await response.json();
					setMatchingPeople([]);
					json.forEach((data:any) => {
						setMatchingPeople((prevData:MatchingPeople[]) => [...prevData, data.fullName])
					})
			} catch (error) {
				return error;
			}
		}, [])
	return (
		<div className="button-modal-container">
			<Button onClick={handleOpen} variant="contained">Create Account User</Button>
				<Modal
					open={open}
					onClose={handleClose}
					aria-labelledby="modal-modal-title"
					aria-describedby="modal-modal-description"
				>
				<Box sx={style}>
					<Form
						schema={schema}
						uiSchema={uiSchema}
						validator={validator}
						onChange={onChange}
						onSubmit={onSubmit}
						onError={log('errors')}
					>
					</Form>
				</Box>
				</Modal>
		</div>
	)
}