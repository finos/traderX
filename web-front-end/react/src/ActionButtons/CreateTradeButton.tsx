import { Box, Button,  MenuItem,  Modal, TextField, ToggleButton, ToggleButtonGroup } from "@mui/material"
import { MouseEvent, useCallback, useRef, useState } from "react";
import { RJSFSchema, } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import Form, { IChangeEvent } from '@rjsf/core';
import { style } from "../style";
import { ActionButtonsProps, RefData, RefDataCompanyNames, Side } from "./types";

export const CreateTradeButton = ({accountId}:ActionButtonsProps) => {
	const [refData, setRefData] = useState<any>([]);
	const tradeId = Math.floor(Math.random() * 1000000)
	const schema: RJSFSchema = {
		title: 'Create Trade',
		type: 'object',
		required: ['security', 'quantity'],
		properties: {
			security: { type: 'string', title: 'Security', enum: refData },
			quantity: { type: 'integer', title: 'Quantity'},
			// side: { type: 'string', title: 'Side', enum: ['Buy', 'Sell'] },
		},
	};
	const uiSchema = {
		"ui:submitButtonOptions": {
			"submitText": "Confirm Details",
			"norender": false,
			"props": {
				"disabled": false,
				"className": "btn btn-info"
			}
		}
	}
	const log = (type:string) => console.log.bind(console, type);
	const handleSubmit = async () => {
		// const tradeDetails = formDataRef.current;
		console.log(security, side, quantity);
		const response = await fetch('http://127.0.0.1:18092/trade/', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				id: `TRADE-${tradeId}`,
				security: security,
				quantity: quantity,
				accountId: accountId,
				side: side,
			}),
		});
		if (response.ok) {
			setOpen(false);
			console.log('success');
		} else {
			console.log('error');
		}
	}
	const [open, setOpen] = useState<boolean>(false);
  const handleClose = () => setOpen(false);
	const handleOpen = async () => {
		setOpen(true);
		try {
			const response = await fetch("http://127.0.0.1:18085/stocks");
			const data = await response.json();
			setRefData(data)
			// data.forEach((refData:RefData) => {
			// 	return (
			// 		setRefData((
			// 			prevData:RefDataCompanyNames[]
			// 			) => [...prevData, refData.ticker]))
			// })
		} catch (error) {
			return error
		}
	}

	const tickerItem = refData.map((option:any) => (
		<MenuItem key={option.ticker} value={option.ticker}>
			{option.ticker}
		</MenuItem>
	))

	const [side, setSide] = useState<Side>();
	const [security, setSecurity] = useState<any>();
	const [quantity, setQuantity] = useState<number>(0);
	const sideRef = useRef<Side>();
	const formDataRef = useRef<any>([]);

  const handleToggleChange = useCallback((
    _event: MouseEvent<HTMLElement>,
		newSide: Side,
  ) => {
		sideRef.current = newSide;
    setSide(newSide);
  }, []);

	const handleSecurityChange = useCallback(
		(event: any) => {
			setSecurity(event.target.value);
	}, [])

	const handleQuantityChange = useCallback(
		(event: any) => {
			setQuantity(event.target.value);
	}, [])

	return (
		<div className="modal-container">
			<Button onClick={handleOpen} variant="contained">Create New Trade</Button>
				<Modal
					open={open}
					onClose={handleClose}
					aria-labelledby="modal-modal-title"
					aria-describedby="modal-modal-description"
				>
				<Box className="modal-components" sx={style}>
					<div>
						<TextField
							select
							label="Security"
							onChange={handleSecurityChange}
						>
							{tickerItem}
						</TextField>
						<TextField
						type="number"
						label="Quantity"
						onChange={handleQuantityChange}
						>

						</TextField>
						<ToggleButtonGroup
							color="primary"
							size="medium"
							style={{height: "3.5em"}}
							value={side}
							exclusive
							onChange={handleToggleChange}
							aria-label="tradeSide"
						>
							<ToggleButton value="Buy">Buy</ToggleButton>
							<ToggleButton value="Sell">Sell</ToggleButton>
						</ToggleButtonGroup>
						<div style={{float: 'left'}} className="submit-button-container">
							<Button variant="contained" color="success" onClick={handleSubmit}>Submit</Button>
						</div>
					</div>
				</Box>
				</Modal>
		</div>
	)
}