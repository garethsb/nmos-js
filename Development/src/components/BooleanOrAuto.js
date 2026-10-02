import React from 'react';
import CheckIcon from '@material-ui/icons/Check';
import ClearIcon from '@material-ui/icons/Clear';
import { makeStyles } from '@material-ui/core/styles';
import get from 'lodash/get';
import { SelectField, SelectInput } from 'react-admin';

// Match BooleanField: a small icon in a flex line, so it stays one text line tall.
const useStyles = makeStyles({
    value: {
        display: 'flex',
    },
});

const choices = [
    { id: true, name: <CheckIcon /> },
    { id: false, name: <ClearIcon /> },
    { id: 'auto', name: 'auto' },
];

const showChoices = [
    { id: true, name: <CheckIcon fontSize="small" /> },
    { id: false, name: <ClearIcon fontSize="small" /> },
    { id: 'auto', name: 'auto' },
];

export const BooleanOrAutoField = props => {
    const classes = useStyles();
    const value = get(props.record, props.source);
    return (
        <SelectField
            {...props}
            className={
                value === true || value === false ? classes.value : undefined
            }
            choices={showChoices}
            translateChoice={false}
        />
    );
};
BooleanOrAutoField.defaultProps = {
    addLabel: true,
};

export const BooleanOrAutoInput = props => (
    <SelectInput {...props} choices={choices} translateChoice={false} />
);
