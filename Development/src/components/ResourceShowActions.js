import React from 'react';
import { EditButton, ListButton, TopToolbar } from 'react-admin';
import RawButton from './RawButton';

const ResourceShowActions = ({ basePath, data, resource }) => (
    <TopToolbar>
        {data ? <RawButton record={data} resource={resource} /> : null}
        <ListButton title={'Return to ' + basePath} basePath={basePath} />
        {data ? <EditButton record={data} basePath={basePath} /> : null}
    </TopToolbar>
);

export default ResourceShowActions;
